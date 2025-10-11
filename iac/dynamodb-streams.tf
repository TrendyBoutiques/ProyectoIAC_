# ============================================================================
# DYNAMODB STREAMS - TRIGGERS Y EVENT SOURCE MAPPINGS
# ============================================================================

# Lambda para procesar eventos del Stream de Cards
data "archive_file" "lambda_card_stream_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../card"
  output_path = "${path.module}/bin/card-stream-processor.zip"
}

# IAM Role para Card Stream Processor
resource "aws_iam_role" "lambda_card_stream_processor_role" {
  name = "${var.project_name}-card-stream-processor-role"
  
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

# Grupo de logs para Card Stream Processor
resource "aws_cloudwatch_log_group" "card_stream_processor_logs" {
  name              = "/aws/lambda/${var.project_name}-card-stream-processor"
  retention_in_days = var.cloudwatch_log_retention_days
  
  tags = var.common_tags
}

# Política para leer DynamoDB Streams
resource "aws_iam_policy" "card_stream_policy" {
  name        = "${var.project_name}-card-stream-policy"
  description = "Permisos para leer el stream de Cards"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = aws_dynamodb_table.cards_table.stream_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-card-stream-processor:*"
      }
    ]
  })
  
  tags = var.common_tags
}

# Lambda function Card Stream Processor
resource "aws_lambda_function" "card_stream_processor" {
  function_name    = "${var.project_name}-card-stream-processor"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_card_stream_processor_role.arn
  filename         = data.archive_file.lambda_card_stream_processor.output_path
  source_code_hash = data.archive_file.lambda_card_stream_processor.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  
  environment {
    variables = {
      CARDS_TABLE = aws_dynamodb_table.cards_table.name
      LOG_LEVEL   = var.log_level
      REGION      = var.aws_region
    }
  }
  
  tags = var.common_tags
  
  depends_on = [
    aws_cloudwatch_log_group.card_stream_processor_logs
  ]
}

# Event Source Mapping - Cards Stream -> Lambda
resource "aws_lambda_event_source_mapping" "cards_stream_trigger" {
  event_source_arn  = aws_dynamodb_table.cards_table.stream_arn
  function_name     = aws_lambda_function.card_stream_processor.arn
  starting_position = var.dynamodb_stream_starting_position
  enabled           = var.enable_cards_stream_processor
  
  # Configuración de batch
  batch_size                         = var.dynamodb_stream_batch_size
  maximum_batching_window_in_seconds = var.dynamodb_stream_batch_window
  parallelization_factor             = var.dynamodb_stream_parallelization_factor
  
  # Configuración de reintentos
  maximum_retry_attempts = var.dynamodb_stream_max_retry_attempts
  maximum_record_age_in_seconds = var.dynamodb_stream_max_record_age
  
  # Split batch on error
  function_response_types = ["ReportBatchItemFailures"]
  
  # Destination on failure (opcional - enviar a SQS DLQ)
  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.card_stream_dlq.arn
    }
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.card_stream_policy_attach
  ]
}

# DLQ para errores del Card Stream
resource "aws_sqs_queue" "card_stream_dlq" {
  name                      = "${var.project_name}-card-stream-dlq"
  message_retention_seconds = var.sqs_dlq_message_retention
  
  tags = merge(
    var.common_tags,
    {
      Purpose = "Dead Letter Queue for Card Stream Processing"
    }
  )
}

# Política para que Lambda pueda enviar a la DLQ
resource "aws_iam_policy" "card_stream_dlq_policy" {
  name        = "${var.project_name}-card-stream-dlq-policy"
  description = "Permisos para enviar mensajes a Card Stream DLQ"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:GetQueueUrl"
      ]
      Resource = aws_sqs_queue.card_stream_dlq.arn
    }]
  })
  
  tags = var.common_tags
}

# ============================================================================
# ORDERS STREAM PROCESSOR
# ============================================================================

# Lambda para procesar eventos del Stream de Orders
data "archive_file" "lambda_order_stream_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../orderandshipping"
  output_path = "${path.module}/bin/order-stream-processor.zip"
}

# IAM Role para Order Stream Processor
resource "aws_iam_role" "lambda_order_stream_processor_role" {
  name = "${var.project_name}-order-stream-processor-role"
  
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

# Grupo de logs para Order Stream Processor
resource "aws_cloudwatch_log_group" "order_stream_processor_logs" {
  name              = "/aws/lambda/${var.project_name}-order-stream-processor"
  retention_in_days = var.cloudwatch_log_retention_days
  
  tags = var.common_tags
}

# Política para leer DynamoDB Streams de Orders
resource "aws_iam_policy" "order_stream_policy" {
  name        = "${var.project_name}-order-stream-policy"
  description = "Permisos para leer el stream de Orders"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = aws_dynamodb_table.orders_table.stream_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-order-stream-processor:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Resource = [
          aws_dynamodb_table.shipping_table.arn,
          aws_dynamodb_table.orders_table.arn
        ]
      }
    ]
  })
  
  tags = var.common_tags
}

# Lambda function Order Stream Processor
resource "aws_lambda_function" "order_stream_processor" {
  function_name    = "${var.project_name}-order-stream-processor"
  handler          = "index.handler"
  runtime          = var.lambda_runtime
  role             = aws_iam_role.lambda_order_stream_processor_role.arn
  filename         = data.archive_file.lambda_order_stream_processor.output_path
  source_code_hash = data.archive_file.lambda_order_stream_processor.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  
  environment {
    variables = {
      ORDERS_TABLE   = aws_dynamodb_table.orders_table.name
      SHIPPING_TABLE = aws_dynamodb_table.shipping_table.name
      LOG_LEVEL      = var.log_level
      REGION         = var.aws_region
    }
  }
  
  tags = var.common_tags
  
  depends_on = [
    aws_cloudwatch_log_group.order_stream_processor_logs
  ]
}

# Event Source Mapping - Orders Stream -> Lambda
resource "aws_lambda_event_source_mapping" "orders_stream_trigger" {
  event_source_arn  = aws_dynamodb_table.orders_table.stream_arn
  function_name     = aws_lambda_function.order_stream_processor.arn
  starting_position = var.dynamodb_stream_starting_position
  enabled           = var.enable_orders_stream_processor
  
  # Configuración de batch
  batch_size                         = var.dynamodb_stream_batch_size
  maximum_batching_window_in_seconds = var.dynamodb_stream_batch_window
  parallelization_factor             = var.dynamodb_stream_parallelization_factor
  
  # Configuración de reintentos
  maximum_retry_attempts = var.dynamodb_stream_max_retry_attempts
  maximum_record_age_in_seconds = var.dynamodb_stream_max_record_age
  
  # Split batch on error
  function_response_types = ["ReportBatchItemFailures"]
  
  # Destination on failure
  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.order_stream_dlq.arn
    }
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.order_stream_policy_attach
  ]
}

# DLQ para errores del Order Stream
resource "aws_sqs_queue" "order_stream_dlq" {
  name                      = "${var.project_name}-order-stream-dlq"
  message_retention_seconds = var.sqs_dlq_message_retention
  
  tags = merge(
    var.common_tags,
    {
      Purpose = "Dead Letter Queue for Order Stream Processing"
    }
  )
}

# Política para que Lambda pueda enviar a la DLQ
resource "aws_iam_policy" "order_stream_dlq_policy" {
  name        = "${var.project_name}-order-stream-dlq-policy"
  description = "Permisos para enviar mensajes a Order Stream DLQ"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:GetQueueUrl"
      ]
      Resource = aws_sqs_queue.order_stream_dlq.arn
    }]
  })
  
  tags = var.common_tags
}

# ============================================================================
# IAM POLICY ATTACHMENTS
# ============================================================================

# Card Stream Processor attachments
resource "aws_iam_role_policy_attachment" "card_stream_policy_attach" {
  role       = aws_iam_role.lambda_card_stream_processor_role.name
  policy_arn = aws_iam_policy.card_stream_policy.arn
}

resource "aws_iam_role_policy_attachment" "card_stream_dlq_attach" {
  role       = aws_iam_role.lambda_card_stream_processor_role.name
  policy_arn = aws_iam_policy.card_stream_dlq_policy.arn
}

resource "aws_iam_role_policy_attachment" "card_stream_basic_execution" {
  role       = aws_iam_role.lambda_card_stream_processor_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Order Stream Processor attachments
resource "aws_iam_role_policy_attachment" "order_stream_policy_attach" {
  role       = aws_iam_role.lambda_order_stream_processor_role.name
  policy_arn = aws_iam_policy.order_stream_policy.arn
}

resource "aws_iam_role_policy_attachment" "order_stream_dlq_attach" {
  role       = aws_iam_role.lambda_order_stream_processor_role.name
  policy_arn = aws_iam_policy.order_stream_dlq_policy.arn
}

resource "aws_iam_role_policy_attachment" "order_stream_basic_execution" {
  role       = aws_iam_role.lambda_order_stream_processor_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================================
# CLOUDWATCH ALARMS PARA STREAMS
# ============================================================================

# Alarma para mensajes en Card Stream DLQ
resource "aws_cloudwatch_metric_alarm" "card_stream_dlq_messages" {
  alarm_name          = "${var.project_name}-card-stream-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alarma cuando hay mensajes en la DLQ del Card Stream"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    QueueName = aws_sqs_queue.card_stream_dlq.name
  }
  
  tags = var.common_tags
}

# Alarma para mensajes en Order Stream DLQ
resource "aws_cloudwatch_metric_alarm" "order_stream_dlq_messages" {
  alarm_name          = "${var.project_name}-order-stream-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alarma cuando hay mensajes en la DLQ del Order Stream"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    QueueName = aws_sqs_queue.order_stream_dlq.name
  }
  
  tags = var.common_tags
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "card_stream_processor_function_name" {
  description = "Nombre de la función Lambda Card Stream Processor"
  value       = aws_lambda_function.card_stream_processor.function_name
}

output "order_stream_processor_function_name" {
  description = "Nombre de la función Lambda Order Stream Processor"
  value       = aws_lambda_function.order_stream_processor.function_name
}

output "card_stream_dlq_url" {
  description = "URL de la DLQ del Card Stream"
  value       = aws_sqs_queue.card_stream_dlq.url
}

output "order_stream_dlq_url" {
  description = "URL de la DLQ del Order Stream"
  value       = aws_sqs_queue.order_stream_dlq.url
}