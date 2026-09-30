output "table_name" {
  value = aws_dynamodb_table.links.name
}

output "lambda_function_name" {
  value = aws_lambda_function.url_shortener.function_name
}