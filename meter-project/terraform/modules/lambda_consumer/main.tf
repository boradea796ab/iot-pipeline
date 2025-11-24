

resource "aws_lambda_function" "iot_consumer" {
  function_name    = "iot-consumer"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.iot_consumer.output_path
  source_code_hash = data.archive_file.iot_consumer.output_base64sha256
  timeout          = 30

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN             = var.secretsmanager_aurora_arn
      DLQ_URL                   = var.dlq_id
      IDEMPOTENCY_TABLE         = var.idempotency_table
      PAYLOAD_RETENTION_SECONDS = tostring(var.payload_retention_seconds)
      READINGS_TABLE            = var.readings_table_name
    }
  }
}
