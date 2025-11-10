resource "aws_lambda_function" "dlq_processor" {
  function_name = "iot-dlq-processor"
  role          = aws_iam_role.dlq_lambda_role.arn
  runtime       = "python3.12"
  handler       = "lambda_dlq_processor.lambda_handler"
  filename         = data.archive_file.dlq_processor.output_path
  source_code_hash = data.archive_file.dlq_processor.output_base64sha256
  timeout       = 30

  environment {
    variables = {
      DLQ_URL                   = var.dlq_id
      IDEMPOTENCY_TABLE         = var.idempotency_table
      PAYLOAD_RETENTION_SECONDS = tostring(var.payload_retention_seconds)
    }
  }
}
