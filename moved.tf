moved {
  from = aws_dynamodb_table.links
  to   = module.dynamodb.aws_dynamodb_table.this
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

moved {
  from = aws_sns_topic.alerts
  to   = module.monitoring.aws_sns_topic.this
}

moved {
  from = aws_sns_topic_subscription.email
  to   = module.monitoring.aws_sns_topic_subscription.email
}

moved {
  from = aws_cloudwatch_metric_alarm.lambda_errors
  to   = module.monitoring.aws_cloudwatch_metric_alarm.lambda_errors
}

moved {
  from = aws_cloudwatch_metric_alarm.api_5xx
  to   = module.monitoring.aws_cloudwatch_metric_alarm.api_5xx
}