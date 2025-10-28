# ----------------------------------------------------------
# 1️⃣  JSON Schema model definition
# ----------------------------------------------------------
resource "aws_api_gateway_model" "iot_reading_model" {
  rest_api_id  = aws_api_gateway_rest_api.iot_api.id
  name         = "IoTReadingModel"
  description  = "Schema for incoming IoT meter readings"
  content_type = "application/json"

  schema = jsonencode({
    type       = "object",
    required   = ["meter_id", "timestamp", "reading_value"],
    properties = {
      meter_id = { type = "string" },
      timestamp = { type = "string", format = "date-time" },
      reading_value = { type = "number" }
    },
    additionalProperties = false
  })
}

# ----------------------------------------------------------
# 2️⃣  Request validator (body only)
# ----------------------------------------------------------
resource "aws_api_gateway_request_validator" "body_validator" {
  rest_api_id                     = aws_api_gateway_rest_api.iot_api.id
  name                            = "BodyValidator"
  validate_request_body            = true
  validate_request_parameters      = false
}
