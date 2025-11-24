resource "aws_lambda_event_source_mapping" "dlq_trigger" {
  event_source_arn = var.dlq_sqs_arn
  function_name    = aws_lambda_function.dlq_processor.arn
  batch_size       = 20
  maximum_batching_window_in_seconds = 10
  enabled          = true
}
