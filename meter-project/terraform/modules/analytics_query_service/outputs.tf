output "lambda_function_name" {
  description = "Analytics query Lambda function name."
  value       = aws_lambda_function.analytics_query.function_name
}

output "lambda_function_arn" {
  description = "Analytics query Lambda ARN."
  value       = aws_lambda_function.analytics_query.arn
}

output "api_id" {
  description = "HTTP API ID for analytics query service."
  value       = aws_apigatewayv2_api.analytics.id
}

output "api_endpoint" {
  description = "Base endpoint for analytics query HTTP API."
  value       = aws_apigatewayv2_api.analytics.api_endpoint
}

output "api_stage_name" {
  description = "Analytics query API stage name."
  value       = aws_apigatewayv2_stage.analytics.name
}

output "health_url" {
  description = "Health endpoint URL."
  value       = "${aws_apigatewayv2_api.analytics.api_endpoint}/${aws_apigatewayv2_stage.analytics.name}/health"
}

output "timeseries_query_url" {
  description = "Timeseries query endpoint URL."
  value       = "${aws_apigatewayv2_api.analytics.api_endpoint}/${aws_apigatewayv2_stage.analytics.name}/query/timeseries"
}

output "statistics_query_url" {
  description = "Statistics query endpoint URL."
  value       = "${aws_apigatewayv2_api.analytics.api_endpoint}/${aws_apigatewayv2_stage.analytics.name}/query/statistics"
}
