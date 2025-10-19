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

resource "aws_api_gateway_method" "ingest_post" {
    rest_api_id = aws_api_gateway_rest_api.iot_api.id
    resource_id = aws_api_gateway_resource.ingest.id
    http_method = "POST"
    authorization = "NONE"
}

resource "aws_api_gateway_method_response" "ingest_200" {
    rest_api_id = aws_api_gateway_rest_api.iot_api.id
    resource_id = aws_api_gateway_resource.ingest.id
    http_method = aws_api_gateway_method.ingest_post.http_method
    status_code = "200"

    response_models = {
      "application/json" = "Empty"
    }
  
}