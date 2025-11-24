resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                   = var.sqs_arn
  function_name                      = aws_lambda_function.iot_consumer.arn
  batch_size                         = var.consumer_max_batch_size
  maximum_batching_window_in_seconds = var.consumer_batch_window_seconds
  enabled                            = true
}
