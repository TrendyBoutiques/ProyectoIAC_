
data "archive_file" "lambda_card" {
  type        = "zip"
  source_dir  = "${path.module}/../card"
  output_path = "${path.module}/bin/card.zip"
}

# IAM Role para Card
resource "aws_iam_role" "lambda_card_exec_role" {
  name = "${var.project_name}-card-exec-role"
  
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
resource "aws_cloudwatch_log_group" "card_logs" {
  name              = "/aws/lambda/${var.project_name}-card"
  retention_in_days = var.cloudwatch_log_retention_days
  
  tags = var.common_tags
}

# Política para CloudWatch Logs
resource "aws_iam_policy" "card_logs_policy" {
  name        = "${var.project_name}-card-logs-policy"
  description = "Permisos para CloudWatch Logs de Card"

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
        "${aws_cloudwatch_log_group.card_logs.arn}",
        "${aws_cloudwatch_log_group.card_logs.arn}:*"
      ]
    }]
  })
  
  tags = var.common_tags
}

# Lambda function Card
resource "aws_lambda_function" "card" {
  function_name    = "${var.project_name}-card"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_card_exec_role.arn
  filename         = data.archive_file.lambda_card.output_path
  source_code_hash = data.archive_file.lambda_card.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      CARDS_TABLE = aws_dynamodb_table.cards_table.name
      USERS_TABLE = aws_dynamodb_table.users_table.name
      LOG_LEVEL   = var.log_level
      PURCHASE_QUEUE_URL = aws_sqs_queue.purchase_queue.url
    }
  }

  tags       = var.common_tags
  depends_on = [
    aws_cloudwatch_log_group.card_logs,
    aws_iam_role_policy_attachment.card_logs_attach,
    aws_iam_role_policy_attachment.card_dynamodb_attach,
    aws_iam_role_policy_attachment.card_kms_attach
  ]
}


# CloudWatch Logs
resource "aws_iam_role_policy_attachment" "card_logs_attach" {
  role       = aws_iam_role.lambda_card_exec_role.name
  policy_arn = aws_iam_policy.card_logs_policy.arn
}

# DynamoDB - Usa la política centralizada de dynamodb.tf
resource "aws_iam_role_policy_attachment" "card_dynamodb_attach" {
  role       = aws_iam_role.lambda_card_exec_role.name
  policy_arn = aws_iam_policy.cards_dynamodb_policy.arn
}

# KMS - Usa la política centralizada de dynamodb.tf
resource "aws_iam_role_policy_attachment" "card_kms_attach" {
  role       = aws_iam_role.lambda_card_exec_role.name
  policy_arn = aws_iam_policy.lambda_kms_policy.arn
}

# Basic Execution (opcional, ya incluido en logs_policy)
resource "aws_iam_role_policy_attachment" "card_basic_execution" {
  role       = aws_iam_role.lambda_card_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}



output "card_lambda_function_name" {
  description = "Nombre de la función Lambda de Card"
  value       = aws_lambda_function.card.function_name
}

output "card_lambda_function_arn" {
  description = "ARN de la función Lambda de Card"
  value       = aws_lambda_function.card.arn
}

output "card_lambda_role_arn" {
  description = "ARN del rol IAM de la Lambda Card"
  value       = aws_iam_role.lambda_card_exec_role.arn
}

output "card_lambda_invoke_arn" {
  description = "ARN de invocación de la Lambda Card"
  value       = aws_lambda_function.card.invoke_arn
}
resource "aws_iam_role_policy_attachment" "card_sqs_attach" {
  role       = aws_iam_role.lambda_card_exec_role.name
  policy_arn = aws_iam_policy.card_sqs_policy.arn
}
