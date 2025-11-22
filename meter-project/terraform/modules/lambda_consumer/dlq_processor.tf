resource "aws_lambda_function" "dlq_processor" {
  function_name    = "iot-dlq-processor"
  role             = aws_iam_role.dlq_lambda_role.arn
  runtime          = "python3.12"
  handler          = "lambda_dlq_processor.lambda_handler"
  filename         = data.archive_file.dlq_processor.output_path
  source_code_hash = data.archive_file.dlq_processor.output_base64sha256
  timeout          = 30

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN             = var.secretsmanager_aurora_arn
      DB_PROXY_ENDPOINT         = var.db_proxy_endpoint
      DLQ_URL                   = var.dlq_id
      DLQ_MAX_ATTEMPTS          = tostring(var.dlq_max_attempts)
      IDEMPOTENCY_TABLE         = var.idempotency_table
      PAYLOAD_RETENTION_SECONDS = tostring(var.payload_retention_seconds)
      READINGS_TABLE            = var.readings_table_name
    }
  }
}
