# Variables adicionales para DynamoDB
variable "dynamodb_billing_mode" {
  description = "Modo de facturación para DynamoDB"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "dynamodb_deletion_protection" {
  default     = false
}

variable "enable_dynamodb_point_in_time_recovery" {
  description = "Habilitar recuperación point-in-time para DynamoDB"
  type        = bool
  default     = true
}

variable "kms_key_deletion_window" {
  description = "Ventana de eliminación para clave KMS (días)"
  type        = number
  default     = 7
}

variable "enable_kms_key_rotation" {
  description = "Habilitar rotación automática de clave KMS"
  type        = bool
  default     = true
}

# Clave KMS para cifrado de DynamoDB
resource "aws_kms_key" "dynamodb_key" {
  description             = "Clave KMS para DynamoDB ${var.project_name}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = var.enable_kms_key_rotation
  policy                  = data.aws_iam_policy_document.kms_policy.json

  tags = var.common_tags
}

resource "aws_kms_alias" "dynamodb_key_alias" {
  name          = "alias/dynamodb-${var.project_name}"
  target_key_id = aws_kms_key.dynamodb_key.key_id
}

# Política para la clave KMS
data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow Lambda access"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.lambda_registrations_exec_role.arn,
        aws_iam_role.lambda_catalogo_exec_role.arn,
        aws_iam_role.lambda_card_exec_role.arn,
        aws_iam_role.lambda_orderandshipping_exec_role.arn
      ]
    }
  }
}

# ============================================================================
# TABLAS DYNAMODB
# ============================================================================

# Tabla para Usuarios/Registrations
resource "aws_dynamodb_table" "users_table" {
  name                        = "${var.project_name}-users"
  billing_mode                = var.dynamodb_billing_mode
  hash_key                    = "userId"
  deletion_protection_enabled = var.dynamodb_deletion_protection
  
  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "accountType"
    type = "S"
  }

  attribute {
    name = "creationDate"
    type = "N"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "AccountTypeIndex"
    hash_key        = "accountType"
    range_key       = "creationDate"
    projection_type = "INCLUDE"
    non_key_attributes = ["userId", "email", "status"]
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "creationDate"
    projection_type = "KEYS_ONLY"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  tags = var.common_tags
}

# Tabla para Productos/Catalogo
resource "aws_dynamodb_table" "products_table" {
  name                        = "${var.project_name}-products"
  billing_mode                = var.dynamodb_billing_mode
  hash_key                    = "productId"
  deletion_protection_enabled = var.dynamodb_deletion_protection
  
  attribute {
    name = "productId"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "creationDate"
    type = "N"
  }

  attribute {
    name = "price"
    type = "N"
  }

  global_secondary_index {
    name            = "CategoryIndex"
    hash_key        = "category"
    range_key       = "creationDate"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "creationDate"
    projection_type = "INCLUDE"
    non_key_attributes = ["productId", "title", "price", "category"]
  }

  global_secondary_index {
    name            = "PriceIndex"
    hash_key        = "category"
    range_key       = "price"
    projection_type = "INCLUDE"
    non_key_attributes = ["productId", "title", "status"]
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  tags = var.common_tags
}

# Tabla para Tarjetas/Cards
resource "aws_dynamodb_table" "cards_table" {
  name                        = "${var.project_name}-cards"
  billing_mode                = var.dynamodb_billing_mode
  hash_key                    = "cardId"
  range_key                   = "userId"
  deletion_protection_enabled = var.dynamodb_deletion_protection
  
  attribute {
    name = "cardId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "cardType"
    type = "S"
  }

  attribute {
    name = "creationDate"
    type = "N"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "UserCardsIndex"
    hash_key        = "userId"
    range_key       = "creationDate"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "CardTypeIndex"
    hash_key        = "cardType"
    range_key       = "creationDate"
    projection_type = "INCLUDE"
    non_key_attributes = ["cardId", "userId", "status"]
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "creationDate"
    projection_type = "KEYS_ONLY"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  tags = var.common_tags
}

# Tabla para Órdenes/Orders
resource "aws_dynamodb_table" "orders_table" {
  name                        = "${var.project_name}-orders"
  billing_mode                = var.dynamodb_billing_mode
  hash_key                    = "orderId"
  deletion_protection_enabled = var.dynamodb_deletion_protection
  
  attribute {
    name = "orderId"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "orderDate"
    type = "N"
  }

  attribute {
    name = "totalAmount"
    type = "N"
  }

  global_secondary_index {
    name            = "UserOrdersIndex"
    hash_key        = "userId"
    range_key       = "orderDate"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "orderDate"
    projection_type = "INCLUDE"
    non_key_attributes = ["orderId", "userId", "totalAmount"]
  }

  global_secondary_index {
    name            = "AmountIndex"
    hash_key        = "userId"
    range_key       = "totalAmount"
    projection_type = "INCLUDE"
    non_key_attributes = ["orderId", "status", "orderDate"]
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  tags = var.common_tags
}

# Tabla para Items de Órdenes
resource "aws_dynamodb_table" "order_items_table" {
  name                        = "${var.project_name}-order-items"
  billing_mode                = var.dynamodb_billing_mode
  hash_key                    = "orderId"
  range_key                   = "productId"
  deletion_protection_enabled = var.dynamodb_deletion_protection
  
  attribute {
    name = "orderId"
    type = "S"
  }

  attribute {
    name = "productId"
    type = "S"
  }

  attribute {
    name = "quantity"
    type = "N"
  }

  global_secondary_index {
    name            = "ProductOrdersIndex"
    hash_key        = "productId"
    range_key       = "quantity"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  tags = var.common_tags
}

# Tabla para Shipping/Envíos
resource "aws_dynamodb_table" "shipping_table" {
  name                        = "${var.project_name}-shipping"
  billing_mode                = var.dynamodb_billing_mode
  hash_key                    = "shippingId"
  deletion_protection_enabled = var.dynamodb_deletion_protection
  
  attribute {
    name = "shippingId"
    type = "S"
  }

  attribute {
    name = "orderId"
    type = "S"
  }

  attribute {
    name = "trackingNumber"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "creationDate"
    type = "N"
  }

  global_secondary_index {
    name            = "OrderShippingIndex"
    hash_key        = "orderId"
    range_key       = "creationDate"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "TrackingIndex"
    hash_key        = "trackingNumber"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "status"
    range_key       = "creationDate"
    projection_type = "INCLUDE"
    non_key_attributes = ["shippingId", "orderId", "trackingNumber"]
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn
  }

  point_in_time_recovery {
    enabled = var.enable_dynamodb_point_in_time_recovery
  }

  tags = var.common_tags
}

# ============================================================================
# POLÍTICAS DYNAMODB
# ============================================================================

resource "aws_iam_policy" "users_dynamodb_policy" {
  name        = "${var.project_name}-UsersDynamoDBPolicy"
  description = "Acceso a la tabla de usuarios"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "UserTableAccess",
      Effect = "Allow",
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
      Resource = [
        aws_dynamodb_table.users_table.arn,
        "${aws_dynamodb_table.users_table.arn}/index/*"
      ]
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_policy" "cards_dynamodb_policy" {
  name        = "${var.project_name}-CardsDynamoDBPolicy"
  description = "Acceso a la tabla de tarjetas y usuarios"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "CardsTableAccess",
      Effect = "Allow",
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
      Resource = [
        aws_dynamodb_table.cards_table.arn,
        "${aws_dynamodb_table.cards_table.arn}/index/*",
        aws_dynamodb_table.users_table.arn,
        "${aws_dynamodb_table.users_table.arn}/index/*"
      ]
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_policy" "products_dynamodb_policy" {
  name        = "${var.project_name}-ProductsDynamoDBPolicy"
  description = "Acceso a la tabla de productos"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "ProductsTableAccess",
      Effect = "Allow",
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
      Resource = [
        aws_dynamodb_table.products_table.arn,
        "${aws_dynamodb_table.products_table.arn}/index/*"
      ]
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_policy" "orders_dynamodb_policy" {
  name        = "${var.project_name}-OrdersDynamoDBPolicy"
  description = "Acceso a las tablas de órdenes, items y shipping"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "OrdersTableAccess",
      Effect = "Allow",
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
      Resource = [
        aws_dynamodb_table.orders_table.arn,
        "${aws_dynamodb_table.orders_table.arn}/index/*",
        aws_dynamodb_table.order_items_table.arn,
        "${aws_dynamodb_table.order_items_table.arn}/index/*",
        aws_dynamodb_table.shipping_table.arn,
        "${aws_dynamodb_table.shipping_table.arn}/index/*",
        aws_dynamodb_table.products_table.arn,
        "${aws_dynamodb_table.products_table.arn}/index/*"
      ]
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_policy" "lambda_kms_policy" {
  name        = "${var.project_name}-LambdaKMSPolicy"
  description = "Permisos para KMS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["kms:Decrypt", "kms:GenerateDataKey"],
      Resource = [aws_kms_key.dynamodb_key.arn]
    }]
  })

  tags = var.common_tags
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "users_table_name" {
  description = "Nombre de la tabla de usuarios"
  value       = aws_dynamodb_table.users_table.name
}

output "users_table_arn" {
  description = "ARN de la tabla de usuarios"
  value       = aws_dynamodb_table.users_table.arn
}

output "products_table_name" {
  description = "Nombre de la tabla de productos"
  value       = aws_dynamodb_table.products_table.name
}

output "products_table_arn" {
  description = "ARN de la tabla de productos"
  value       = aws_dynamodb_table.products_table.arn
}

output "cards_table_name" {
  description = "Nombre de la tabla de tarjetas"
  value       = aws_dynamodb_table.cards_table.name
}

output "cards_table_arn" {
  description = "ARN de la tabla de tarjetas"
  value       = aws_dynamodb_table.cards_table.arn
}

output "orders_table_name" {
  description = "Nombre de la tabla de órdenes"
  value       = aws_dynamodb_table.orders_table.name
}

output "orders_table_arn" {
  description = "ARN de la tabla de órdenes"
  value       = aws_dynamodb_table.orders_table.arn
}

output "order_items_table_name" {
  description = "Nombre de la tabla de items de órdenes"
  value       = aws_dynamodb_table.order_items_table.name
}

output "order_items_table_arn" {
  description = "ARN de la tabla de items de órdenes"
  value       = aws_dynamodb_table.order_items_table.arn
}

output "shipping_table_name" {
  description = "Nombre de la tabla de shipping"
  value       = aws_dynamodb_table.shipping_table.name
}

output "shipping_table_arn" {
  description = "ARN de la tabla de shipping"
  value       = aws_dynamodb_table.shipping_table.arn
}

output "dynamodb_kms_key_arn" {
  description = "ARN de la clave KMS para DynamoDB"
  value       = aws_kms_key.dynamodb_key.arn
}

output "dynamodb_kms_key_id" {
  description = "ID de la clave KMS para DynamoDB"
  value       = aws_kms_key.dynamodb_key.key_id
}