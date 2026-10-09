output "table_name" {
  value = module.dynamodb.table_name
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "api_url" {
  value = aws_apigatewayv2_api.http.api_endpoint
}