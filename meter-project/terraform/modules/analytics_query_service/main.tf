data "archive_file" "analytics_query" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = var.lambda_zip_path
}

locals {
  invoke_roles = {
    for role_arn in var.invoke_role_arns :
    role_arn => regexreplace(role_arn, "^arn:aws:iam::[0-9]+:role/", "")
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-analytics-query-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-analytics-query-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_ssm_parameter" "influxdb_query_url" {
  name = var.influxdb_query_url_ssm_parameter
}

data "aws_ssm_parameter" "influxdb_read_token" {
  name            = var.influxdb_read_token_ssm_parameter
  with_decryption = true
}

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
  route_key          = "GET /v1/health"
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.analytics_lambda.id}"
}

resource "aws_apigatewayv2_route" "timeseries" {
  api_id             = aws_apigatewayv2_api.analytics.id
  route_key          = "POST /v1/query/timeseries"
  authorization_type = "AWS_IAM"
  target             = "integrations/${aws_apigatewayv2_integration.analytics_lambda.id}"
}

resource "aws_apigatewayv2_route" "statistics" {
  api_id             = aws_apigatewayv2_api.analytics.id
  route_key          = "POST /v1/query/statistics"
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

resource "aws_iam_policy" "api_invoke" {
  count       = length(local.invoke_roles) > 0 ? 1 : 0
  name        = "${var.project_name}-analytics-api-invoke"
  description = "Allows invoke access to analytics query HTTP API routes."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["execute-api:Invoke"]
      Resource = [
        "${aws_apigatewayv2_api.analytics.execution_arn}/${aws_apigatewayv2_stage.analytics.name}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "invoke_access" {
  for_each = local.invoke_roles

  role       = each.value
  policy_arn = aws_iam_policy.api_invoke[0].arn
}

resource "aws_cloudwatch_metric_alarm" "query_errors" {
  alarm_name          = "${var.project_name}-analytics-query-errors"
  namespace           = var.metrics_namespace
  metric_name         = "QueryError"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_description   = "Analytics query API is returning repeated query errors."
}

resource "aws_cloudwatch_metric_alarm" "query_timeouts" {
  alarm_name          = "${var.project_name}-analytics-query-timeouts"
  namespace           = var.metrics_namespace
  metric_name         = "QueryTimeout"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_description   = "Analytics query API is experiencing upstream query timeouts."
}
