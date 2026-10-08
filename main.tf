#################### IAM ####################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "url-shortener-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_dynamodb" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem"]
    resources = [aws_dynamodb_table.links.arn]
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name   = "dynamodb-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_dynamodb.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.url_shortener.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

#################### Lambda ####################
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "url_shortener" {
  #checkov:skip=CKV_AWS_115:Account concurrency limit is 10 and AWS requires 10 unreserved; API Gateway throttling caps traffic instead
  #checkov:skip=CKV_AWS_116:DLQs only apply to async invocations; API Gateway invokes synchronously and errors return to the caller
  #checkov:skip=CKV_AWS_117:Only calls the public DynamoDB endpoint; a VPC would add NAT cost with no security benefit
  #checkov:skip=CKV_AWS_272:Code signing is out of scope; the OIDC-restricted pipeline is the only deploy path
  #checkov:skip=CKV_AWS_173:Env vars hold no secrets (table name only) and are encrypted at rest with an AWS-managed key

  function_name = "url-shortener"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.13"
  handler       = "app.lambda_handler"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.links.name
    }
  }

  tracing_config {
    mode = "Active"
  }
}

#################### Database ####################
resource "aws_dynamodb_table" "links" {
  #checkov:skip=CKV_AWS_119:Encrypted at rest by default with an AWS-owned key; data is public URLs, so a customer-managed key adds cost without benefit

  name         = "url-shortener-links"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"

  attribute {
    name = "short_code"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
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
  integration_uri        = aws_lambda_function.url_shortener.invoke_arn
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
  dimensions          = { FunctionName = aws_lambda_function.url_shortener.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  ok_actions = [aws_sns_topic.alerts.arn]
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
  ok_actions = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_log_group" "api_access" {
  #checkov:skip=CKV_AWS_158:CloudWatch Logs are already encrypted at rest by default.
  #checkov:skip=CKV_AWS_338:Data minimization, access logs contain visitor's IP addresses which counts as personal data and I have no need to keep them for a long time
  name              = "/aws/apigateway/url-shortener-access"
  retention_in_days = 14
}