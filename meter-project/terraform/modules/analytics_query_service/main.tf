data "archive_file" "analytics_query" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = var.lambda_zip_path
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
      }
    ]
  })
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

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = var.lambda_security_group_ids
  }

  environment {
    variables = {
      SERVICE_NAME = "analytics-query"
      STUB_MODE    = "true"
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
  api_id    = aws_apigatewayv2_api.analytics.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.analytics_lambda.id}"
}

resource "aws_apigatewayv2_route" "query" {
  api_id    = aws_apigatewayv2_api.analytics.id
  route_key = "POST /query"
  target    = "integrations/${aws_apigatewayv2_integration.analytics_lambda.id}"
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
