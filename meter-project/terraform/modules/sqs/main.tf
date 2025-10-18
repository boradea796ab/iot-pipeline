resource "aws_sqs_queue" "iot_queue" {
  name                      = var.queue_name
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 0
  # fifo_queue = false     # uncomment later if you move to FIFO
}