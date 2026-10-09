#################### IAM ####################


#################### Database ####################
module "dynamodb" {
  source     = "./modules/dynamodb"
  table_name = "url-shortener-links"
}

moved {
  from = aws_dynamodb_table.links
  to   = module.dynamodb.aws_dynamodb_table.this
}

#################### Lambda ####################
module "lambda" {
  source        = "./modules/lambda"
  function_name = "url-shortener"
  role_name     = "url-shortener-lambda"
  source_dir    = "${path.module}/lambda"
  table_name    = module.dynamodb.table_name
  table_arn     = module.dynamodb.table_arn
}

moved {
  from = aws_lambda_function.url_shortener
  to   = module.lambda.aws_lambda_function.this
}

moved {
  from = aws_iam_role.lambda
  to   = module.lambda.aws_iam_role.this
}

moved {
  from = aws_iam_role_policy.lambda_dynamodb
  to   = module.lambda.aws_iam_role_policy.dynamodb
}

moved {
  from = aws_iam_role_policy_attachment.lambda_logs
  to   = module.lambda.aws_iam_role_policy_attachment.logs
}

moved {
  from = aws_iam_role_policy_attachment.lambda_xray
  to   = module.lambda.aws_iam_role_policy_attachment.xray
}

#################### API Gateway ####################
module "api" {
  source               = "./modules/api"
  api_name             = "url-shortener-api"
  lambda_function_name = module.lambda.function_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  log_group_name       = "/aws/apigateway/url-shortener-access"
}

moved {
  from = aws_apigatewayv2_api.http
  to   = module.api.aws_apigatewayv2_api.this
}

moved {
  from = aws_apigatewayv2_stage.default
  to   = module.api.aws_apigatewayv2_stage.default
}

moved {
  from = aws_apigatewayv2_integration.lambda
  to   = module.api.aws_apigatewayv2_integration.lambda
}

moved {
  from = aws_apigatewayv2_route.create_link
  to   = module.api.aws_apigatewayv2_route.create_link
}

moved {
  from = aws_apigatewayv2_route.redirect
  to   = module.api.aws_apigatewayv2_route.redirect
}

moved {
  from = aws_lambda_permission.api_gateway
  to   = module.api.aws_lambda_permission.api_gateway
}

moved {
  from = aws_cloudwatch_log_group.api_access
  to   = module.api.aws_cloudwatch_log_group.access
}

##################### Monitoring #####################
resource "aws_sns_topic" "alerts" {
  #checkov:skip=CKV_AWS_26:Free aws-managed SNS key can't be used by CloudWatch alarms
  name = "url-shortener-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "url-shortener-lambda-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = module.lambda.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "url-shortener-api-5xx"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5xx"
  dimensions          = { ApiId = module.api.api_id }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  ok_actions          = [aws_sns_topic.alerts.arn]
}

