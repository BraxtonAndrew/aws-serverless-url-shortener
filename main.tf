#################### IAM ####################
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

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
resource "aws_apigatewayv2_api" "http" {
  name          = "url-shortener-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 5
    throttling_burst_limit = 10
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      latency        = "$context.responseLatency"
      integrationErr = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = module.lambda.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_link" {
  #checkov:skip=CKV_AWS_309:Public by design for this demo; throttled at the stage. Future improvement: add a JWT authorizer to POST /links

  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /links"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "redirect" {
  #checkov:skip=CKV_AWS_309:Redirect must be publicly accessible; that is the core function of a URL shortener

  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /{code}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
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
  dimensions          = { ApiId = aws_apigatewayv2_api.http.id }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  ok_actions          = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_log_group" "api_access" {
  #checkov:skip=CKV_AWS_158:CloudWatch Logs are already encrypted at rest by default.
  #checkov:skip=CKV_AWS_338:Data minimization, access logs contain visitor's IP addresses which counts as personal data and I have no need to keep them for a long time
  name              = "/aws/apigateway/url-shortener-access"
  retention_in_days = 14
}