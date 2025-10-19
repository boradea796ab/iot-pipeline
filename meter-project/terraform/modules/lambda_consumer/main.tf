

resource "aws_lambda_function" "iot_consumer" {
  function_name = "iot-consumer"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "lambda_function.lambda_handler"
  filename      = "${path.module}/lambda_consumer.zip"
  timeout       = 30
}