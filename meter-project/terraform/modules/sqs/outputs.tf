output "sqs_url" {
  description = "URL of the IoT SQS queue"
  value       = aws_sqs_queue.iot_queue.id
}

output "sqs_arn" {
  description = "ARN of the IoT SQS queue"
  value       = aws_sqs_queue.iot_queue.arn
}
