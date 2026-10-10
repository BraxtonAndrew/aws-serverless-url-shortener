module "dynamodb" {
  source     = "./modules/dynamodb"
  table_name = "url-shortener-links"
}

module "lambda" {
  source        = "./modules/lambda"
  function_name = "url-shortener"
  role_name     = "url-shortener-lambda"
  source_dir    = "${path.module}/lambda"
  table_name    = module.dynamodb.table_name
  table_arn     = module.dynamodb.table_arn
}

module "api" {
  source               = "./modules/api"
  api_name             = "url-shortener-api"
  lambda_function_name = module.lambda.function_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  log_group_name       = "/aws/apigateway/url-shortener-access"
}

module "monitoring" {
  source               = "./modules/monitoring"
  name_prefix          = "url-shortener"
  alert_email          = var.alert_email
  lambda_function_name = module.lambda.function_name
  api_id               = module.api.api_id
}

