resource "aws_api_gateway_deployment" "iot_deploy" {
  rest_api_id = aws_api_gateway_rest_api.iot_api.id
  depends_on = [
    aws_api_gateway_integration.health_mock,
    aws_api_gateway_integration_response.health_200_integration,
    aws_api_gateway_integration.ingest_post,
    aws_api_gateway_integration_response.ingest_200_integration
  ]

  triggers = {
    redeployment = sha1(jsonencode({
      token = var.force_redeploy_token
    }))
  }

  lifecycle {
    create_before_destroy = true
  }

  description = "SQS integration deployment with updated IAM new"
}


resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.iot_api.id
  deployment_id = aws_api_gateway_deployment.iot_deploy.id
  stage_name    = var.stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_logs.arn
    format = jsonencode({
      requestId           = "$context.requestId",
      ip                  = "$context.identity.sourceIp",
      caller              = "$context.identity.caller",
      user                = "$context.identity.user",
      requestTime         = "$context.requestTime",
      httpMethod          = "$context.httpMethod",
      resourcePath        = "$context.resourcePath",
      status              = "$context.status",
      protocol            = "$context.protocol",
      responseLength      = "$context.responseLength",
      integrationLatency  = "$context.integrationLatency",
      errorMessage        = "$context.error.message",
      integrationError    = "$context.integration.error",
      integrationStatus   = "$context.integration.status"
    })
  }

  depends_on = [aws_cloudwatch_log_group.apigw_logs]
}

resource "aws_api_gateway_method_settings" "example" {
  rest_api_id = aws_api_gateway_rest_api.iot_api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}
