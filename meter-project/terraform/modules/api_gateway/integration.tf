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