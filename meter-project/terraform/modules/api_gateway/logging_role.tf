# ############################################################
# # 🔧 API Gateway → CloudWatch logging permission
# ############################################################

resource "aws_iam_role" "apigw_cloudwatch_role" {
  name = "apigw-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "apigateway.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "apigw_cloudwatch_policy" {
  role = aws_iam_role.apigw_cloudwatch_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# # Attach the role at account level
resource "aws_api_gateway_account" "account_settings" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn
}
