output "sqs_url" {
  description = "URL of the IoT SQS queue"
  value       = aws_sqs_queue.iot_queue.id
}

output "sqs_arn" {
  description = "ARN of the IoT SQS queue"
  value       = aws_sqs_queue.iot_queue.arn
}

output "sqs_name" {
  value = aws_sqs_queue.iot_queue.name
}

output "dlq_sqs_arn" {
  description = "ARN of the IoT SQS DLQ"
  value       = aws_sqs_queue.iot_dlq.arn
}

output "dlq_id" {
  description = "ARN of the IoT SQS DLQ"
  value       = aws_sqs_queue.iot_dlq.id
}

output "dlq_name" {
  description = "Name of the DLQ used for monitoring dashboards"
  value       = aws_sqs_queue.iot_dlq.name
}
