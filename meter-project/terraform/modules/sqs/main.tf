resource "aws_sqs_queue" "iot_queue" {
  name                       = var.queue_name
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.iot_dlq.arn
    maxReceiveCount     = 3              # after 3 failures → DLQ
  })
}

# Dead Letter Queue
resource "aws_sqs_queue" "iot_dlq" {
  name = "iot-meter-data-dlq"
  message_retention_seconds = 1209600   # 14 days
}