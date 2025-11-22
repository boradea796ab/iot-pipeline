output "lambda_security_group_id" {
  value = aws_security_group.lambda.id
}

output "consumer_function_name" {
  description = "Name of the main IoT ingestion Lambda function"
  value       = aws_lambda_function.iot_consumer.function_name
}

output "dlq_function_name" {
  description = "Name of the DLQ processing Lambda function"
  value       = aws_lambda_function.dlq_processor.function_name
}
