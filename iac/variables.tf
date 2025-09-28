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

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
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

variable "log_level" {
  description = "Nivel de logs"
  type        = string
  default     = "INFO"
}