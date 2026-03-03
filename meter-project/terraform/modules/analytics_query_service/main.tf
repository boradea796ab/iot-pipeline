resource "aws_cloudwatch_log_group" "analytics_query" {
  name              = "/aws/lambda/${var.project_name}-analytics-query"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "analytics_query" {
  function_name    = "${var.project_name}-analytics-query"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "analytics_query.lambda_handler"
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb
  filename         = data.archive_file.analytics_query.output_path
  source_code_hash = data.archive_file.analytics_query.output_base64sha256

  reserved_concurrent_executions = var.lambda_reserved_concurrency

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.lambda_security_group_ids
  }

  environment {
    variables = {
      SERVICE_NAME          = "analytics-query"
      INFLUX_QUERY_API_URL  = data.aws_ssm_parameter.influxdb_query_url.value
      INFLUX_READ_TOKEN     = data.aws_ssm_parameter.influxdb_read_token.value
      INFLUX_ORG            = var.influx_org
      INFLUX_HOT_BUCKET     = var.influx_hot_bucket_name
      INFLUX_COLD_BUCKET    = var.influx_cold_bucket_name
      HOT_RETENTION_DAYS    = tostring(var.hot_retention_days)
      MAX_LOOKBACK_DAYS     = tostring(var.max_lookback_days)
      MAX_SERIES_LIMIT      = tostring(var.max_series_limit)
      MAX_METER_IDS         = tostring(var.max_meter_ids)
      QUERY_TIMEOUT_SECONDS = tostring(var.query_timeout_seconds)
      METRICS_NAMESPACE     = var.metrics_namespace
    }
  }

  depends_on = [aws_cloudwatch_log_group.analytics_query]
}

resource "aws_apigatewayv2_api" "analytics" {
  name          = "${var.project_name}-analytics-query-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "analytics_lambda" {
  api_id                 = aws_apigatewayv2_api.analytics.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  payload_format_version = "2.0"
  integration_uri        = aws_lambda_function.analytics_query.invoke_arn
}

resource "aws_apigatewayv2_route" "health" {
  api_id             = aws_apigatewayv2_api.analytics.id
  route_key          = "GET /health"
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.analytics_lambda.id}"
}

resource "aws_apigatewayv2_route" "timeseries" {
  api_id             = aws_apigatewayv2_api.analytics.id
  route_key          = "POST /query/timeseries"
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.analytics_lambda.id}"
}

resource "aws_apigatewayv2_route" "statistics" {
  api_id             = aws_apigatewayv2_api.analytics.id
  route_key          = "POST /query/statistics"
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.analytics_lambda.id}"
}

resource "aws_apigatewayv2_stage" "analytics" {
  api_id      = aws_apigatewayv2_api.analytics.id
  name        = var.api_stage_name
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics_query.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.analytics.execution_arn}/*/*"
}
