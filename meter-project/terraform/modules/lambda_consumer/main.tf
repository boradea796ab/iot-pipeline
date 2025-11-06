

resource "aws_lambda_function" "iot_consumer" {
  function_name = "iot-consumer"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"
  filename         = data.archive_file.iot_consumer.output_path
  source_code_hash = data.archive_file.iot_consumer.output_base64sha256
  timeout       = 30

  environment {
    variables = {
      DLQ_URL = var.dlq_id
    }
  }
}
