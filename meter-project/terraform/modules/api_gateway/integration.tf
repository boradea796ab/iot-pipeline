data "aws_caller_identity" "current" {}

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
      depends_on = [
    aws_api_gateway_integration.health_mock
  ]
}

resource "aws_api_gateway_integration" "ingest_post" {
  rest_api_id             = aws_api_gateway_rest_api.iot_api.id
  resource_id             = aws_api_gateway_resource.ingest.id
  http_method             = aws_api_gateway_method.ingest_post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri = "arn:aws:apigateway:${var.region}:sqs:path/${data.aws_caller_identity.current.account_id}/${var.queue_name}"
  credentials             = aws_iam_role.apigw_sqs_role.arn

  # Required: map JSON to SQS form request
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  cache_key_parameters = ["integration.request.header.Content-Type"]

  # JSON → form-encoded transformation
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
}

resource "aws_api_gateway_integration_response" "ingest_200_integration" {
    rest_api_id = aws_api_gateway_rest_api.iot_api.id
    resource_id = aws_api_gateway_resource.ingest.id
    http_method = aws_api_gateway_method.ingest_post.http_method
    status_code = aws_api_gateway_method_response.ingest_200.status_code
  response_templates = {
    "application/json" = <<EOF
        {
          "status": "ok",
          "messageId": "$input.path('$.SendMessageResponse.SendMessageResult.MessageId')"
        }
      EOF
  }
    depends_on = [
    aws_api_gateway_integration.ingest_post
    ]
}
