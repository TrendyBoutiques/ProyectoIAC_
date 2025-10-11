variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "ecommerce"
}


variable "api_gateway_domain_name" {
  description = "API Gateway domain name"
  type        = string
  default     = ""
}

variable "callback_urls" {
  description = "List of allowed callback URLs"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

variable "logout_urls" {
  description = "List of allowed logout URLs"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  type        = string
  default     = ""
}

variable "api_gateway_integration_timeout_ms" {
  description = "API Gateway integration timeout in milliseconds"
  type        = number
  default     = 29000
}

variable "enable_api_gateway_logging" {
  description = "Enable API Gateway logging to CloudWatch"
  type        = bool
  default     = true
}



variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit"
  type        = number
  default     = 100
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 200
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "ecommerce"
    ManagedBy   = "terraform"
  }
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-2"
}

variable "lambda_runtime" {
  description = "Runtime para las funciones Lambda"
  type        = string
  default     = "nodejs16.x"
}

variable "lambda_timeout" {
  description = "Timeout para las funciones Lambda"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memoria para las funciones Lambda"
  type        = number
  default     = 256
}


# ============================================================================
# VARIABLES ADICIONALES PARA SQS
# ============================================================================

variable "sqs_visibility_timeout" {
  description = "Timeout de visibilidad para mensajes SQS (segundos)"
  type        = number
  default     = 300 # 5 minutos - debe ser >= lambda timeout
}

variable "sqs_message_retention" {
  description = "Tiempo de retención de mensajes en SQS (segundos)"
  type        = number
  default     = 345600 # 4 días
}

variable "sqs_dlq_message_retention" {
  description = "Tiempo de retención de mensajes en DLQ (segundos)"
  type        = number
  default     = 1209600 # 14 días
}

variable "sqs_receive_wait_time" {
  description = "Tiempo de espera para long polling (segundos)"
  type        = number
  default     = 20
}

variable "sqs_max_receive_count" {
  description = "Número máximo de recepciones antes de enviar a DLQ"
  type        = number
  default     = 3
}

variable "sqs_batch_size" {
  description = "Tamaño de batch para procesamiento de mensajes SQS"
  type        = number
  default     = 10
}

variable "sqs_batch_window" {
  description = "Ventana de tiempo para agrupar mensajes (segundos)"
  type        = number
  default     = 5
}

variable "sqs_maximum_concurrency" {
  description = "Concurrencia máxima para procesamiento de SQS"
  type        = number
  default     = 10
}

# ============================================================================
# VARIABLES ADICIONALES PARA LAMBDA PURCHASE
# ============================================================================

variable "lambda_timeout_purchase" {
  description = "Timeout para Lambda Purchase (segundos)"
  type        = number
  default     = 60
}

variable "lambda_memory_size_purchase" {
  description = "Memoria para Lambda Purchase (MB)"
  type        = number
  default     = 512
}

variable "lambda_reserved_concurrency_purchase" {
  description = "Concurrencia reservada para Lambda Purchase"
  type        = number
  default     = 5
}

# ============================================================================
# VARIABLES PARA DYNAMODB STREAMS
# ============================================================================

variable "dynamodb_stream_starting_position" {
  description = "Posición de inicio para leer el stream"
  type        = string
  default     = "LATEST" # Opciones: LATEST, TRIM_HORIZON
  
  validation {
    condition     = contains(["LATEST", "TRIM_HORIZON"], var.dynamodb_stream_starting_position)
    error_message = "La posición debe ser LATEST o TRIM_HORIZON."
  }
}

variable "dynamodb_stream_batch_size" {
  description = "Tamaño de batch para procesamiento de streams"
  type        = number
  default     = 100
  
  validation {
    condition     = var.dynamodb_stream_batch_size >= 1 && var.dynamodb_stream_batch_size <= 10000
    error_message = "El batch size debe estar entre 1 y 10000."
  }
}

variable "dynamodb_stream_batch_window" {
  description = "Ventana de tiempo para agrupar registros del stream (segundos)"
  type        = number
  default     = 5
  
  validation {
    condition     = var.dynamodb_stream_batch_window >= 0 && var.dynamodb_stream_batch_window <= 300
    error_message = "El batch window debe estar entre 0 y 300 segundos."
  }
}

variable "dynamodb_stream_parallelization_factor" {
  description = "Número de procesadores paralelos por shard"
  type        = number
  default     = 1
  
  validation {
    condition     = var.dynamodb_stream_parallelization_factor >= 1 && var.dynamodb_stream_parallelization_factor <= 10
    error_message = "El factor de paralelización debe estar entre 1 y 10."
  }
}

variable "dynamodb_stream_max_retry_attempts" {
  description = "Número máximo de reintentos para registros fallidos"
  type        = number
  default     = 3
  
  validation {
    condition     = var.dynamodb_stream_max_retry_attempts >= -1 && var.dynamodb_stream_max_retry_attempts <= 10000
    error_message = "Los reintentos deben estar entre -1 (infinitos) y 10000."
  }
}

variable "dynamodb_stream_max_record_age" {
  description = "Edad máxima de un registro antes de descartarlo (segundos)"
  type        = number
  default     = 604800 # 7 días
  
  validation {
    condition     = var.dynamodb_stream_max_record_age >= -1 && var.dynamodb_stream_max_record_age <= 604800
    error_message = "La edad máxima debe estar entre -1 (sin límite) y 604800 segundos (7 días)."
  }
}

variable "enable_cards_stream_processor" {
  description = "Habilitar procesamiento del stream de Cards"
  type        = bool
  default     = true
}

variable "enable_orders_stream_processor" {
  description = "Habilitar procesamiento del stream de Orders"
  type        = bool
  default     = true
}

# ============================================================================
# VARIABLES EXISTENTES QUE PUEDEN NECESITAR AJUSTE
# ============================================================================

# Si no existe, agregar:
variable "log_level" {
  description = "Nivel de logging para Lambdas"
  type        = string
  default     = "INFO"
  
  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.log_level)
    error_message = "El log level debe ser DEBUG, INFO, WARN o ERROR."
  }
}

variable "cloudwatch_log_retention_days" {
  description = "Días de retención para logs de CloudWatch"
  type        = number
  default     = 7
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.cloudwatch_log_retention_days)
    error_message = "Debe ser un valor válido de retención de CloudWatch Logs."
  }
}



# ============================================================================
# VARIABLES PARA LAMBDA SEND EMAILS ORDER
# ============================================================================

variable "lambda_timeout_send_emails" {
  description = "Timeout para Lambda Send Emails Order (segundos)"
  type        = number
  default     = 30
}

variable "lambda_reserved_concurrency_send_emails" {
  description = "Concurrencia reservada para Lambda Send Emails Order"
  type        = number
  default     = 2
}

# ============================================================================
# VARIABLES PARA SQS EMAILS
# ============================================================================

variable "sqs_visibility_timeout_emails" {
  description = "Timeout de visibilidad para mensajes SQS de emails (segundos)"
  type        = number
  default     = 60 # Debe ser >= lambda_timeout_send_emails
}

variable "sqs_batch_size_emails" {
  description = "Tamaño de batch para procesamiento de mensajes SQS de emails"
  type        = number
  default     = 5
}

variable "sqs_maximum_concurrency_emails" {
  description = "Concurrencia máxima para procesamiento de SQS de emails"
  type        = number
  default     = 5
}