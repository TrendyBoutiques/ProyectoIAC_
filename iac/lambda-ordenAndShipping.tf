data "archive_file" "lambda_orderandshipping" {
  type        = "zip"
  source_dir  = "${path.module}/../orderandshipping"
  output_path = "${path.module}/bin/orderandshipping.zip"
}

# IAM Role para Order and Shipping
resource "aws_iam_role" "lambda_orderandshipping_exec_role" {
  name = "${var.project_name}-orderandshipping-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  
  tags = var.common_tags
}

# Grupo de logs con retención configurable
resource "aws_cloudwatch_log_group" "orderandshipping_logs" {
  name              = "/aws/lambda/${var.project_name}-orderandshipping"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.common_tags
}

# Política para CloudWatch Logs
resource "aws_iam_policy" "orderandshipping_logs_policy" {
  name        = "${var.project_name}-orderandshipping-logs-policy"
  description = "Permisos para CloudWatch Logs de Order and Shipping"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect   = "Allow",
      Resource = [
        "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-orderandshipping:*"
      ]
    }]
  })
}

# Política para DynamoDB
resource "aws_iam_policy" "orderandshipping_dynamodb_policy" {
  name        = "${var.project_name}-orderandshipping-dynamodb-policy"
  description = "Permisos para DynamoDB de Order and Shipping"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      Effect = "Allow",
      Resource = [
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-orders",
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-orders/index/*",
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-products",
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-products/index/*"
      ]
    }]
  })
}

# Política para SES (envío de emails)
resource "aws_iam_policy" "orderandshipping_ses_policy" {
  name        = "${var.project_name}-orderandshipping-ses-policy"
  description = "Permisos para SES de Order and Shipping"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      Effect = "Allow",
      Resource = "*"
    }]
  })
}

# Lambda function Order and Shipping
resource "aws_lambda_function" "orderandshipping" {
  function_name    = "${var.project_name}-orderandshipping"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_orderandshipping_exec_role.arn
  filename         = data.archive_file.lambda_orderandshipping.output_path
  source_code_hash = data.archive_file.lambda_orderandshipping.output_base64sha256
  timeout          = 60  # Mayor timeout para procesamiento de órdenes
  memory_size      = 512 # Mayor memoria para procesamiento de órdenes
  
  environment {
    variables = {
      ORDERS_TABLE   = "${var.project_name}-orders"
      PRODUCTS_TABLE = "${var.project_name}-products"
      LOG_LEVEL      = var.log_level
    }
  }
  
  tags       = var.common_tags
  depends_on = [aws_cloudwatch_log_group.orderandshipping_logs]
}

# Attachments para Order and Shipping
resource "aws_iam_role_policy_attachment" "orderandshipping_logs_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = aws_iam_policy.orderandshipping_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "orderandshipping_dynamodb_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = aws_iam_policy.orderandshipping_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "orderandshipping_ses_attach" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = aws_iam_policy.orderandshipping_ses_policy.arn
}

resource "aws_iam_role_policy_attachment" "orderandshipping_basic_execution" {
  role       = aws_iam_role.lambda_orderandshipping_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
