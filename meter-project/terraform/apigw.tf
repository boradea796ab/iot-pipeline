resource "aws_api_gateway_rest_api" "iot_api" {
  name = "iot-ingestion-api"
  description = "Minimal mock API for health check"
  endpoint_configuration {
    types = ["EDGE"] # publicly available via AWS global edge network
  }
}

resource "aws_api_gateway_resource" "health" {
    rest_api_id = aws_api_gateway_rest_api.iot_api.id
    parent_id = aws_api_gateway_rest_api.iot_api.root_resource_id
    path_part = "health"
}

resource "aws_api_gateway_method" "health_get" {
    rest_api_id = aws_api_gateway_rest_api.iot_api.id
    resource_id = aws_api_gateway_resource.health.id
    http_method = "GET"
    authorization = "NONE"
}

resource "aws_api_gateway_method_response" "health_200" {
    rest_api_id = aws_api_gateway_rest_api.iot_api.id
    resource_id = aws_api_gateway_resource.health.id
    http_method = aws_api_gateway_method.health_get.http_method
    status_code = "200"

    response_models = {
      "application/json" = "Empty"
    }
  
}

resource "aws_api_gateway_integration" "health_mock" {
    rest_api_id = aws_api_gateway_rest_api.iot_api.id
    resource_id = aws_api_gateway_resource.health.id
    http_method = aws_api_gateway_method.health_get.http_method
    type = "MOCK"
    integration_http_method = "GET"

    request_templates = {
      "application/json" = <<EOF
      {
        "statusCode": 200
      }
      EOF
    }
}

resource "aws_api_gateway_integration_response" "health_200_integration" {
    rest_api_id = aws_api_gateway_rest_api.iot_api.id
    resource_id = aws_api_gateway_resource.health.id
    http_method = aws_api_gateway_method.health_get.http_method
    status_code = aws_api_gateway_method_response.health_200.status_code
    response_templates = {
      "application/json" = <<EOF
      {
        "status": "ok",
        "message": "Hello from API Gateway!"
      }
      EOF 
    }
}

resource "aws_api_gateway_deployment" "hello_deploy" {
  rest_api_id = aws_api_gateway_rest_api.iot_api.id
  depends_on = [
    aws_api_gateway_integration.health_mock,
    aws_api_gateway_integration_response.health_200_integration
  ]

  description = "Initial deployment of mock API"
}


resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.iot_api.id
  deployment_id = aws_api_gateway_deployment.hello_deploy.id
  stage_name    = "prod"
}


output "api_base_url" {
  value = aws_api_gateway_deployment.hello_deploy.invoke_url
  description = "Public base URL of the Hello API Gateway"
}
