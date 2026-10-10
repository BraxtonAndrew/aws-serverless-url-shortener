variable "name_prefix" {
  type        = string
  description = "Prefix for monitoring resource names"
}

variable "alert_email" {
  type        = string
  description = "Email address for alarm notifications"
  sensitive   = true
}

variable "lambda_function_name" {
  type        = string
  description = "Lambda function to watch for errors"
}

variable "api_id" {
  type        = string
  description = "API Gateway HTTP API to watch for 5xx errors"
}