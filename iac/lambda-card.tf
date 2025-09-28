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
  tags              = var.common_tags
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
      Effect   = "Allow",
      Resource = [
        "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-card:*"
      ]
    }]
  })
}

# Política para DynamoDB
resource "aws_iam_policy" "card_dynamodb_policy" {
  name        = "${var.project_name}-card-dynamodb-policy"
  description = "Permisos para DynamoDB de Card"
  
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
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-cards",
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-cards/index/*",
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-users",
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-users/index/*"
      ]
    }]
  })
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
      CARDS_TABLE = "${var.project_name}-cards"
      USERS_TABLE = "${var.project_name}-users"
      LOG_LEVEL   = var.log_level
    }
  }
  
  tags       = var.common_tags
  depends_on = [aws_cloudwatch_log_group.card_logs]
}

# Attachments para Card
resource "aws_iam_role_policy_attachment" "card_logs_attach" {
  role       = aws_iam_role.lambda_card_exec_role.name
  policy_arn = aws_iam_policy.card_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "card_dynamodb_attach" {
  role       = aws_iam_role.lambda_card_exec_role.name
  policy_arn = aws_iam_policy.card_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "card_basic_execution" {
  role       = aws_iam_role.lambda_card_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}