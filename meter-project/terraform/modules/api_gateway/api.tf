resource "aws_api_gateway_rest_api" "iot_api" {
  name = var.api_name
  description = var.description
  endpoint_configuration {
    types = ["EDGE"] # publicly available via AWS global edge network
  }
}

resource "aws_api_gateway_resource" "health" {
    rest_api_id = aws_api_gateway_rest_api.iot_api.id
    parent_id = aws_api_gateway_rest_api.iot_api.root_resource_id
    path_part = "health"
}