locals {
  invoke_roles = {
    for role_arn in var.invoke_role_arns :
    role_arn => element(split("/", role_arn), length(split("/", role_arn)) - 1)
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-analytics-query-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-analytics-query-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "api_invoke" {
  count       = length(local.invoke_roles) > 0 ? 1 : 0
  name        = "${var.project_name}-analytics-api-invoke"
  description = "Allows invoke access to analytics query HTTP API routes."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["execute-api:Invoke"]
      Resource = [
        "${aws_apigatewayv2_api.analytics.execution_arn}/${aws_apigatewayv2_stage.analytics.name}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "invoke_access" {
  for_each = local.invoke_roles

  role       = each.value
  policy_arn = aws_iam_policy.api_invoke[0].arn
}
