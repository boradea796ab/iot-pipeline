############################################################
# HMAC Lambda Authorizer
############################################################

locals {
  device_secret_prefix = trimspace(var.device_secret_parameter_prefix)

  device_secret_env = {
    for device_id, param_name in var.device_secret_parameters :
    "DEVICE_${device_id}_PARAM" => trimspace(param_name)
    if length(trimspace(param_name)) > 0
  }

  device_secret_parameter_resources = distinct(concat(
    [
      for param_name in values(local.device_secret_env) :
      format(
        "arn:aws:ssm:%s:%s:parameter%s",
        var.region,
        data.aws_caller_identity.current.account_id,
        param_name
      )
    ],
    length(local.device_secret_prefix) > 0 ? [
      format(
        "arn:aws:ssm:%s:%s:parameter%s*",
        var.region,
        data.aws_caller_identity.current.account_id,
        local.device_secret_prefix
      )
    ] : []
  ))

  device_secret_policy_statement = length(local.device_secret_parameter_resources) > 0 ? [
    {
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = local.device_secret_parameter_resources
    }
  ] : []
}

resource "aws_lambda_function" "hmac_authorizer" {
  function_name    = "iot-hmac-authorizer"
  role             = aws_iam_role.hmac_authorizer_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = "${path.module}/lambda_authorizer.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_authorizer.zip")

  environment {
    variables = merge(
      {
        DEVICE_SECRET_PARAMETER_PREFIX = local.device_secret_prefix
      },
      local.device_secret_env
    )
  }
}

# Connect Lambda as API Gateway authorizer
resource "aws_api_gateway_authorizer" "hmac_auth" {
  name            = "iot-hmac-authorizer"
  rest_api_id     = aws_api_gateway_rest_api.iot_api.id
  authorizer_uri  = aws_lambda_function.hmac_authorizer.invoke_arn
  type            = "REQUEST"
  identity_source = "method.request.header.x-signature,method.request.header.x-device-id"
}


resource "aws_iam_role" "hmac_authorizer_role" {
  name = "iot-hmac-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "hmac_authorizer_policy" {
  name = "iot-hmac-authorizer-policy"
  role = aws_iam_role.hmac_authorizer_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # Allow CloudWatch logging
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "*"
        }
      ],
      local.device_secret_policy_statement
    )
  })
}

resource "aws_lambda_permission" "allow_apigw_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hmac_authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.iot_api.execution_arn}/authorizers/${aws_api_gateway_authorizer.hmac_auth.id}"
}
