resource "aws_api_gateway_deployment" "hello_deploy" {
  rest_api_id = aws_api_gateway_rest_api.iot_api.id
  depends_on = [
    aws_api_gateway_integration.health_mock,
    aws_api_gateway_integration_response.health_200_integration,
    aws_api_gateway_integration.ingest_post,
    aws_api_gateway_integration_response.ingest_200_integration
  ]

  description = "SQS integration deployment"
}


resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.iot_api.id
  deployment_id = aws_api_gateway_deployment.hello_deploy.id
  stage_name    = var.stage_name
}