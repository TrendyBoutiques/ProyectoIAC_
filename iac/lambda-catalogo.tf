data "archive_file" "lambda_catalogo" {
  type        = "zip"
  source_dir  = "${path.module}/../catalogo"
  output_path = "${path.module}/bin/catalogo.zip"
}

# IAM Role para Catalogo
resource "aws_iam_role" "lambda_catalogo_exec_role" {
  name = "${var.project_name}-catalogo-exec-role"

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
resource "aws_cloudwatch_log_group" "catalogo_logs" {
  name              = "/aws/lambda/${var.project_name}-catalogo"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = var.common_tags
}

# Política para CloudWatch Logs
resource "aws_iam_policy" "catalogo_logs_policy" {
  name        = "${var.project_name}-catalogo-logs-policy"
  description = "Permisos para CloudWatch Logs de Catalogo"
  
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
        "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-catalogo:*"
      ]
    }]
  })
}

# Política para DynamoDB
resource "aws_iam_policy" "catalogo_dynamodb_policy" {
  name        = "${var.project_name}-catalogo-dynamodb-policy"
  description = "Permisos para DynamoDB de Catalogo"
  
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
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-products",
        "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-products/index/*"
      ]
    }]
  })
}

# Lambda function Catalogo
resource "aws_lambda_function" "catalogo" {
  function_name    = "${var.project_name}-catalogo"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_catalogo_exec_role.arn
  filename         = data.archive_file.lambda_catalogo.output_path
  source_code_hash = data.archive_file.lambda_catalogo.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  
  environment {
    variables = {
      PRODUCTS_TABLE = "${var.project_name}-products"
      LOG_LEVEL      = var.log_level
    }
  }
  
  tags       = var.common_tags
  depends_on = [aws_cloudwatch_log_group.catalogo_logs]
}

# Attachments para Catalogo
resource "aws_iam_role_policy_attachment" "catalogo_logs_attach" {
  role       = aws_iam_role.lambda_catalogo_exec_role.name
  policy_arn = aws_iam_policy.catalogo_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "catalogo_dynamodb_attach" {
  role       = aws_iam_role.lambda_catalogo_exec_role.name
  policy_arn = aws_iam_policy.catalogo_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "catalogo_basic_execution" {
  role       = aws_iam_role.lambda_catalogo_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}