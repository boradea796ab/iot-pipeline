resource "aws_lambda_event_source_mapping" "dlq_trigger" {
  event_source_arn = var.dlq_sqs_arn
  function_name    = aws_lambda_function.dlq_processor.arn
  batch_size       = 5
  enabled          = true
}
