data "archive_file" "lambda_registrations" {
  type        = "zip"
  source_dir  = "${path.module}/../registrations"
  output_path = "${path.module}/bin/registrations.zip"
}

# IAM Role para Registrations
resource "aws_iam_role" "lambda_registrations_exec_role" {
  name = "${var.project_name}-registrations-exec-role"

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
resource "aws_cloudwatch_log_group" "registrations_logs" {
  name              = "/aws/lambda/${var.project_name}-registrations"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.common_tags
}

# Política para CloudWatch Logs
resource "aws_iam_policy" "registrations_logs_policy" {
  name        = "${var.project_name}-registrations-logs-policy"
  description = "Permisos para CloudWatch Logs de Registrations"
  
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
        "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-registrations:*"
      ]
    }]
  })
}

# Política para DynamoDB
resource "aws_iam_policy" "registrations_dynamodb_policy" {
  name        = "${var.project_name}-registrations-dynamodb-policy"
  description = "Permisos para DynamoDB de Registrations"
  
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
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-users",
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-users/index/*"
      ]
    }]
  })
}

# Lambda function Registrations
resource "aws_lambda_function" "registrations" {
  function_name    = "${var.project_name}-registrations"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_registrations_exec_role.arn
  filename         = data.archive_file.lambda_registrations.output_path
  source_code_hash = data.archive_file.lambda_registrations.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  
  environment {
    variables = {
      USERS_TABLE = "${var.project_name}-users"
      LOG_LEVEL   = var.log_level
    }
  }
  
  tags       = var.common_tags
  depends_on = [aws_cloudwatch_log_group.registrations_logs]
}

# Attachments para Registrations
resource "aws_iam_role_policy_attachment" "registrations_logs_attach" {
  role       = aws_iam_role.lambda_registrations_exec_role.name
  policy_arn = aws_iam_policy.registrations_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "registrations_dynamodb_attach" {
  role       = aws_iam_role.lambda_registrations_exec_role.name
  policy_arn = aws_iam_policy.registrations_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "registrations_basic_execution" {
  role       = aws_iam_role.lambda_registrations_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}