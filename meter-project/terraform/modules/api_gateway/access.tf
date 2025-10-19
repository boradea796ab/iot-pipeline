resource "aws_iam_role" "apigw_sqs_role" {
  name = "apigw-sqs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "apigw_sqs_policy" {
  role = aws_iam_role.apigw_sqs_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["sqs:SendMessage"]
      Resource = var.queue_arn
    }]
  })
}


resource "aws_sqs_queue_policy" "allow_apigw" {
  queue_url = var.queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.apigw_sqs_role.arn
        }
        Action = "sqs:SendMessage"
        Resource = var.queue_arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "${aws_api_gateway_rest_api.iot_api.execution_arn}/prod/POST/ingest"
          }
        }
      }
    ]
  })
}