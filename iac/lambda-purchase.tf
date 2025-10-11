# ============================================================================
# LAMBDA PURCHASE - PROCESA COMPRAS DESDE SQS
# ============================================================================

# Empaquetar código de Purchase
data "archive_file" "lambda_purchase" {
  type        = "zip"
  source_dir  = "${path.module}/../orderandshipping"
  output_path = "${path.module}/bin/purchase.zip"
}

# IAM Role para Purchase
resource "aws_iam_role" "lambda_purchase_exec_role" {
  name = "${var.project_name}-purchase-exec-role"
  
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
resource "aws_cloudwatch_log_group" "purchase_logs" {
  name              = "/aws/lambda/${var.project_name}-purchase"
  retention_in_days = var.cloudwatch_log_retention_days
  
  tags = var.common_tags
}

# Política para CloudWatch Logs
resource "aws_iam_policy" "purchase_logs_policy" {
  name        = "${var.project_name}-purchase-logs-policy"
  description = "Permisos para CloudWatch Logs de Purchase"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      Effect = "Allow",
      Resource = [
        "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-purchase:*"
      ]
    }]
  })
  
  tags = var.common_tags
}

# Política para DynamoDB (Purchase necesita acceso a Orders, OrderItems, Products, Shipping)
resource "aws_iam_policy" "purchase_dynamodb_policy" {
  name        = "${var.project_name}-purchase-dynamodb-policy"
  description = "Permisos para DynamoDB de Purchase"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem"
      ],
      Effect = "Allow",
      Resource = [
        aws_dynamodb_table.orders_table.arn,
        "${aws_dynamodb_table.orders_table.arn}/index/*",
        aws_dynamodb_table.order_items_table.arn,
        "${aws_dynamodb_table.order_items_table.arn}/index/*",
        aws_dynamodb_table.products_table.arn,
        "${aws_dynamodb_table.products_table.arn}/index/*",
        aws_dynamodb_table.shipping_table.arn,
        "${aws_dynamodb_table.shipping_table.arn}/index/*",
        aws_dynamodb_table.cards_table.arn,
        "${aws_dynamodb_table.cards_table.arn}/index/*"
      ]
    }]
  })
  
  tags = var.common_tags
}

# Política para KMS (DynamoDB encryption)
resource "aws_iam_policy" "purchase_kms_policy" {
  name        = "${var.project_name}-purchase-kms-policy"
  description = "Permisos KMS para Purchase"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ]
      Resource = [
        aws_kms_key.dynamodb_key.arn,
        aws_kms_key.sqs_key.arn
      ]
    }]
  })
  
  tags = var.common_tags
}

# Lambda function Purchase
resource "aws_lambda_function" "purchase" {
  function_name    = "${var.project_name}-purchase"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_purchase_exec_role.arn
  filename         = data.archive_file.lambda_purchase.output_path
  source_code_hash = data.archive_file.lambda_purchase.output_base64sha256
  timeout          = var.lambda_timeout_purchase
  memory_size      = var.lambda_memory_size_purchase
  
  environment {
    variables = {
      ORDERS_TABLE       = aws_dynamodb_table.orders_table.name
      ORDER_ITEMS_TABLE  = aws_dynamodb_table.order_items_table.name
      PRODUCTS_TABLE     = aws_dynamodb_table.products_table.name
      SHIPPING_TABLE     = aws_dynamodb_table.shipping_table.name
      CARDS_TABLE        = aws_dynamodb_table.cards_table.name
      LOG_LEVEL          = var.log_level
      REGION             = var.aws_region
    }
  }
  
  
  
  tags = var.common_tags
  
  depends_on = [
    aws_cloudwatch_log_group.purchase_logs,
    aws_iam_role_policy_attachment.purchase_logs_attach,
    aws_iam_role_policy_attachment.purchase_dynamodb_attach,
    aws_iam_role_policy_attachment.purchase_sqs_attach,
    aws_iam_role_policy_attachment.purchase_kms_attach
  ]
}

# Event Source Mapping - Conectar SQS con Lambda
resource "aws_lambda_event_source_mapping" "purchase_sqs_trigger" {
  event_source_arn = aws_sqs_queue.purchase_queue.arn
  function_name    = aws_lambda_function.purchase.arn
  enabled          = true
  batch_size       = var.sqs_batch_size
  
  # Configuración de batch window
  maximum_batching_window_in_seconds = var.sqs_batch_window
  
  # Configuración de reintentos y manejo de errores
  function_response_types = ["ReportBatchItemFailures"]
  
  scaling_config {
    maximum_concurrency = var.sqs_maximum_concurrency
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.purchase_sqs_attach
  ]
}

# ============================================================================
# IAM POLICY ATTACHMENTS
# ============================================================================

resource "aws_iam_role_policy_attachment" "purchase_logs_attach" {
  role       = aws_iam_role.lambda_purchase_exec_role.name
  policy_arn = aws_iam_policy.purchase_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "purchase_dynamodb_attach" {
  role       = aws_iam_role.lambda_purchase_exec_role.name
  policy_arn = aws_iam_policy.purchase_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "purchase_sqs_attach" {
  role       = aws_iam_role.lambda_purchase_exec_role.name
  policy_arn = aws_iam_policy.purchase_sqs_policy.arn
}

resource "aws_iam_role_policy_attachment" "purchase_kms_attach" {
  role       = aws_iam_role.lambda_purchase_exec_role.name
  policy_arn = aws_iam_policy.purchase_kms_policy.arn
}

resource "aws_iam_role_policy_attachment" "purchase_basic_execution" {
  role       = aws_iam_role.lambda_purchase_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================================
# CLOUDWATCH ALARMS
# ============================================================================

# Alarma para errores en Purchase
resource "aws_cloudwatch_metric_alarm" "purchase_errors" {
  alarm_name          = "${var.project_name}-purchase-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alarma cuando Purchase tiene muchos errores"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.purchase.function_name
  }
  
  tags = var.common_tags
}

# Alarma para throttling en Purchase
resource "aws_cloudwatch_metric_alarm" "purchase_throttles" {
  alarm_name          = "${var.project_name}-purchase-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarma cuando Purchase está siendo throttled"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.purchase.function_name
  }
  
  tags = var.common_tags
}

# Alarma para mensajes en DLQ
resource "aws_cloudwatch_metric_alarm" "purchase_dlq_messages" {
  alarm_name          = "${var.project_name}-purchase-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alarma cuando hay mensajes en la DLQ de Purchase"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    QueueName = aws_sqs_queue.purchase_dlq.name
  }
  
  tags = var.common_tags
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "purchase_function_name" {
  description = "Nombre de la función Lambda Purchase"
  value       = aws_lambda_function.purchase.function_name
}

output "purchase_function_arn" {
  description = "ARN de la función Lambda Purchase"
  value       = aws_lambda_function.purchase.arn
}

output "purchase_role_arn" {
  description = "ARN del rol IAM de Purchase"
  value       = aws_iam_role.lambda_purchase_exec_role.arn
}

output "purchase_log_group" {
  description = "Nombre del log group de Purchase"
  value       = aws_cloudwatch_log_group.purchase_logs.name
}