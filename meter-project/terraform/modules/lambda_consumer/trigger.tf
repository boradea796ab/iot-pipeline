resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_arn
  function_name    = aws_lambda_function.iot_consumer.arn
  batch_size       = 10
  enabled          = true
}
