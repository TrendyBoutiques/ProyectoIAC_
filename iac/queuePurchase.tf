# ============================================================================
# SQS QUEUES
# ============================================================================

# Dead Letter Queue para Purchase
resource "aws_sqs_queue" "purchase_dlq" {
  name                      = "${var.project_name}-purchase-dlq"
  message_retention_seconds = var.sqs_dlq_message_retention
  
  tags = merge(
    var.common_tags,
    {
      Purpose = "Dead Letter Queue for Purchase"
    }
  )
}

# Cola principal para Purchase
resource "aws_sqs_queue" "purchase_queue" {
  name                       = "${var.project_name}-purchase-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  delay_seconds              = 0
  receive_wait_time_seconds  = var.sqs_receive_wait_time
  max_message_size           = 262144 # 256 KB
  
  # Configuración de Dead Letter Queue
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.purchase_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })
  
  # Encriptación con KMS
  
  kms_master_key_id       = aws_kms_key.sqs_key.id
  kms_data_key_reuse_period_seconds = 300
  
  tags = merge(
    var.common_tags,
    {
      Purpose = "Purchase Queue"
    }
  )
}

# Clave KMS para SQS
resource "aws_kms_key" "sqs_key" {
  description             = "Clave KMS para SQS ${var.project_name}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.enable_kms_key_rotation
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda to use the key"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow SQS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = var.common_tags
}

resource "aws_kms_alias" "sqs_key_alias" {
  name          = "alias/sqs-${var.project_name}"
  target_key_id = aws_kms_key.sqs_key.key_id
}

# ============================================================================
# SQS POLICIES
# ============================================================================

# Política para que Lambda Card pueda enviar mensajes
resource "aws_sqs_queue_policy" "purchase_queue_policy" {
  queue_url = aws_sqs_queue.purchase_queue.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaCardSendMessage"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_card_exec_role.arn
        }
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.purchase_queue.arn
      },
      {
        Sid    = "AllowLambdaPurchaseReceiveMessage"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_purchase_exec_role.arn
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.purchase_queue.arn
      }
    ]
  })
}

# ============================================================================
# IAM POLICIES PARA SQS
# ============================================================================

# Política para Card (Productor)
resource "aws_iam_policy" "card_sqs_policy" {
  name        = "${var.project_name}-card-sqs-policy"
  description = "Permisos para que Card envíe mensajes a Purchase Queue"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.purchase_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.sqs_key.arn
      }
    ]
  })
  
  tags = var.common_tags
}

# Política para Purchase (Consumidor)
resource "aws_iam_policy" "purchase_sqs_policy" {
  name        = "${var.project_name}-purchase-sqs-policy"
  description = "Permisos para que Purchase reciba mensajes de la cola"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.purchase_queue.arn,
          aws_sqs_queue.purchase_dlq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.sqs_key.arn
      }
    ]
  })
  
  tags = var.common_tags
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "purchase_queue_url" {
  description = "URL de la cola de Purchase"
  value       = aws_sqs_queue.purchase_queue.url
}

output "purchase_queue_arn" {
  description = "ARN de la cola de Purchase"
  value       = aws_sqs_queue.purchase_queue.arn
}

output "purchase_dlq_url" {
  description = "URL de la DLQ de Purchase"
  value       = aws_sqs_queue.purchase_dlq.url
}

output "purchase_dlq_arn" {
  description = "ARN de la DLQ de Purchase"
  value       = aws_sqs_queue.purchase_dlq.arn
}

output "sqs_kms_key_arn" {
  description = "ARN de la clave KMS para SQS"
  value       = aws_kms_key.sqs_key.arn
}