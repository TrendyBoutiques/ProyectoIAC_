# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "API Gateway for ${var.project_name} ${var.environment}"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  binary_media_types = ["*/*"]

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-api"
    Environment = var.environment
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Cognito Authorizer (si se proporciona user pool ARN)
resource "aws_api_gateway_authorizer" "cognito" {
  count = var.cognito_user_pool_arn != "" ? 1 : 0
  
  name                   = "${var.project_name}-${var.environment}-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.main.id
  type                   = "COGNITO_USER_POOLS"
  identity_source        = "method.request.header.Authorization"
  provider_arns          = [var.cognito_user_pool_arn]
  authorizer_result_ttl_in_seconds = 300
}

# API Gateway Resource - /api
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "api"
}

# API Gateway Resource - /api/v1
resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "v1"
}

# Define endpoints configuration
locals {
  endpoints = {
    registrations = {
      path_part = "registrations"
      methods = ["POST", "OPTIONS"]
      lambda_invoke_arn = aws_lambda_function.registrations.invoke_arn
      lambda_name = aws_lambda_function.registrations.function_name
      authorization = "NONE"  # No auth for registration
    }
    catalogo = {
      path_part = "catalogo"
      methods = ["GET", "OPTIONS"]
      lambda_invoke_arn = aws_lambda_function.catalogo.invoke_arn
      lambda_name = aws_lambda_function.catalogo.function_name
      authorization = "COGNITO_USER_POOLS"
    }
    orderandshipping = {
      path_part = "orderandshipping"
      methods = ["GET", "POST", "OPTIONS"]
      lambda_invoke_arn = aws_lambda_function.orderandshipping.invoke_arn
      lambda_name = aws_lambda_function.orderandshipping.function_name
      authorization = "COGNITO_USER_POOLS"
    }
    card = {
      path_part = "card"
      methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
      lambda_invoke_arn = aws_lambda_function.card.invoke_arn
      lambda_name = aws_lambda_function.card.function_name
      authorization = "COGNITO_USER_POOLS"
    }
  }
}

# Create resources for each endpoint
resource "aws_api_gateway_resource" "endpoints" {
  for_each = local.endpoints
  
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = each.value.path_part
}

# Create methods for each endpoint (excluding OPTIONS)
resource "aws_api_gateway_method" "endpoint_methods" {
  for_each = {
    for combo in flatten([for endpoint_key, endpoint in local.endpoints : [
      for method in endpoint.methods : {  
        key = "${endpoint_key}_${method}"
        endpoint_key = endpoint_key
        method = method
        authorization = endpoint.authorization
      } if method != "OPTIONS"
    ]]) : combo.key => combo
  }
  
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.endpoints[each.value.endpoint_key].id
  http_method   = each.value.method
  authorization = each.value.authorization == "COGNITO_USER_POOLS" && var.cognito_user_pool_arn != "" ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id = each.value.authorization == "COGNITO_USER_POOLS" && var.cognito_user_pool_arn != "" ? aws_api_gateway_authorizer.cognito[0].id : null

  request_parameters = each.value.authorization == "COGNITO_USER_POOLS" && var.cognito_user_pool_arn != "" ? {
    "method.request.header.Authorization" = true
  } : {}
}

# Create Lambda integrations for each method
resource "aws_api_gateway_integration" "endpoint_integrations" {
  for_each = {
    for combo in flatten([for endpoint_key, endpoint in local.endpoints : [
      for method in endpoint.methods : {
        key = "${endpoint_key}_${method}"
        endpoint_key = endpoint_key
        method = method
        lambda_invoke_arn = endpoint.lambda_invoke_arn
      } if method != "OPTIONS"
    ]]) : combo.key => combo
  }
  
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.endpoints[each.value.endpoint_key].id
  http_method             = aws_api_gateway_method.endpoint_methods[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.lambda_invoke_arn
  timeout_milliseconds    = var.api_gateway_integration_timeout_ms

  depends_on = [aws_api_gateway_method.endpoint_methods]
}

# CORS Configuration
resource "aws_api_gateway_method" "cors_method" {
  for_each = local.endpoints

  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.endpoints[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"

  depends_on = [aws_api_gateway_resource.endpoints]
}

resource "aws_api_gateway_integration" "cors_integration" {
  for_each = local.endpoints

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.endpoints[each.key].id
  http_method = "OPTIONS"
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }

  depends_on = [aws_api_gateway_method.cors_method]
}

resource "aws_api_gateway_method_response" "cors_method_response" {
  for_each = local.endpoints

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.endpoints[each.key].id
  http_method = aws_api_gateway_method.cors_method[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  depends_on = [aws_api_gateway_method.cors_method]
}

resource "aws_api_gateway_integration_response" "cors_integration_response" {
  for_each = local.endpoints

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.endpoints[each.key].id
  http_method = aws_api_gateway_method.cors_method[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'${join(",", each.value.methods)}'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  
  depends_on = [
    aws_api_gateway_integration.cors_integration,
    aws_api_gateway_method_response.cors_method_response
  ]
}

# Lambda permissions
resource "aws_lambda_permission" "api_gateway_permissions" {
  for_each = local.endpoints
  
  statement_id  = "AllowExecutionFromAPIGateway-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      for endpoint_key in keys(local.endpoints) : [
        aws_api_gateway_resource.endpoints[endpoint_key].id,
        [for method_key in keys(aws_api_gateway_method.endpoint_methods) : 
         aws_api_gateway_method.endpoint_methods[method_key].id if startswith(method_key, endpoint_key)],
        [for integration_key in keys(aws_api_gateway_integration.endpoint_integrations) : 
         aws_api_gateway_integration.endpoint_integrations[integration_key].id if startswith(integration_key, endpoint_key)],
        aws_api_gateway_method.cors_method[endpoint_key].id,
        aws_api_gateway_integration.cors_integration[endpoint_key].id,
        aws_api_gateway_method_response.cors_method_response[endpoint_key].id,
        aws_api_gateway_integration_response.cors_integration_response[endpoint_key].id
      ]
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.endpoint_methods,
    aws_api_gateway_integration.endpoint_integrations,
    aws_api_gateway_method.cors_method,
    aws_api_gateway_integration.cors_integration,
    aws_api_gateway_method_response.cors_method_response,
    aws_api_gateway_integration_response.cors_integration_response,
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  stage_name    = var.environment
  rest_api_id   = aws_api_gateway_rest_api.main.id
  deployment_id = aws_api_gateway_deployment.main.id

  depends_on = [aws_api_gateway_account.main]

  dynamic "access_log_settings" {
    for_each = var.enable_api_gateway_logging ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_gateway[0].arn
      format = jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        caller         = "$context.identity.caller"
        user           = "$context.identity.user"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        resourcePath   = "$context.resourcePath"
        status         = "$context.status"
        protocol       = "$context.protocol"
        responseLength = "$context.response.header.Content-Length"
      })
    }
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-api-stage"
    Environment = var.environment
  })
}

# CloudWatch Log Group (conditional)
resource "aws_cloudwatch_log_group" "api_gateway" {
  count             = var.enable_api_gateway_logging ? 1 : 0
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-api-logs"
    Environment = var.environment
  })
}

# IAM Role for API Gateway CloudWatch logs
resource "aws_iam_role" "api_gateway_cloudwatch_logs" {
  count = var.enable_api_gateway_logging ? 1 : 0
  name  = "${var.project_name}-${var.environment}-apigateway-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Sid = ""
      },
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-api-cloudwatch-role"
    Environment = var.environment
  })
}

resource "aws_iam_policy" "api_gateway_cloudwatch_logs_policy" {
  count       = var.enable_api_gateway_logging ? 1 : 0
  name        = "${var.project_name}-${var.environment}-apigateway-cloudwatch-logs-policy"
  description = "Permite a API Gateway escribir logs en CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetResourcePolicy",
          "logs:PutResourcePolicy"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-api-cloudwatch-policy"
    Environment = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_logs_attachment" {
  count      = var.enable_api_gateway_logging ? 1 : 0
  role       = aws_iam_role.api_gateway_cloudwatch_logs[0].name
  policy_arn = aws_iam_policy.api_gateway_cloudwatch_logs_policy[0].arn
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = var.enable_api_gateway_logging ? aws_iam_role.api_gateway_cloudwatch_logs[0].arn : null
  depends_on = [
    aws_iam_role.api_gateway_cloudwatch_logs,
  ]
}

# Outputs
output "api_gateway_rest_api_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_rest_api_arn" {
  description = "ARN of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}"
}

output "api_gateway_stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.main.stage_name
}

output "api_gateway_domain_name" {
  description = "Domain name of the API Gateway"
  value       = "${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
}

output "api_gateway_cloudwatch_logs_role_arn" {
  description = "ARN of the API Gateway CloudWatch logs role"
  value       = var.enable_api_gateway_logging ? aws_iam_role.api_gateway_cloudwatch_logs[0].arn : null
}

# Individual endpoint URLs
output "registrations_endpoint" {
  description = "Registrations endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}/api/v1/registrations"
}

output "catalogo_endpoint" {
  description = "Catalogo endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}/api/v1/catalogo"
}

output "orderandshipping_endpoint" {
  description = "Order and Shipping endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}/api/v1/orderandshipping"
}

output "card_endpoint" {
  description = "Card endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}/api/v1/card"
}
