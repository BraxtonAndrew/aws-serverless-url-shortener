variable "function_name" {
  type        = string
  description = "Name of the Lambda function"
}

variable "role_name" {
  type        = string
  description = "Name of Lambda's IAM role"
}

variable "source_dir" {
  type        = string
  description = "Path to the directory containing the Lambda source code"
}

variable "table_name" {
  type        = string
  description = "Name of the table environment variable"
}

variable "table_arn" {
  type        = string
  description = "ARN of the DynamoDB table, used to scope the IAM policy"
}