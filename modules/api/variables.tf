variable "api_name" {
  type        = string
  description = "Name of the API Gateway HTTP API"
}

variable "lambda_function_name" {
  type        = string
  description = "Name of the Lambda function"
}

variable "lambda_invoke_arn" {
  type        = string
  description = "ARN of Lambda, used to direct the API gateway"
}

variable "log_group_name" {
  type        = string
  description = "Name fo the CloudWatch log group for API access logs"
}

variable "throttling_rate_limit" {
  type        = number
  description = "Steady-state requests per second allowed"
  default     = 5
}

variable "throttling_burst_limit" {
  type        = number
  description = "Simultaneous requests allowed"
  default     = 10
}