output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "invoke_arn" {
  description = "Invoke ARN used by API Gateway integrations"
  value       = aws_lambda_function.this.invoke_arn
}