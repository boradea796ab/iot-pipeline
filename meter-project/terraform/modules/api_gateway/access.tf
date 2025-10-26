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

resource "aws_iam_role_policy_attachment" "apigw_sqs_full_access" {
  role       = aws_iam_role.apigw_sqs_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}
