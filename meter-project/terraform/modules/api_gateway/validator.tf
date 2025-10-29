# ----------------------------------------------------------
# 1️⃣  JSON Schema model definition
# ----------------------------------------------------------
resource "aws_api_gateway_model" "iot_reading_model" {
  rest_api_id  = aws_api_gateway_rest_api.iot_api.id
  name         = "IoTReadingModel"
  description  = "Schema for incoming IoT meter readings"
  content_type = "application/json"

  schema = jsonencode({
    type     = "object",
    required = ["meter_id", "timestamp", "reading_value"],
    properties = {
      meter_id      = { type = "string" },
      timestamp     = { type = "string", format = "date-time" },
      reading_value = { type = "number" }
    },
    additionalProperties = false
  })
}

# ----------------------------------------------------------
# 2️⃣  Request validator (body only)
# ----------------------------------------------------------
resource "aws_api_gateway_request_validator" "body_validator" {
  rest_api_id                 = aws_api_gateway_rest_api.iot_api.id
  name                        = "BodyValidator"
  validate_request_body       = true
  validate_request_parameters = false
}


# ----------------------------------------------------------
# 1️⃣  Extended JSON Schema model
# ----------------------------------------------------------
resource "aws_api_gateway_model" "iot_reading_model_v2" {
  rest_api_id  = aws_api_gateway_rest_api.iot_api.id
  name         = "IoTReadingModelV2"
  description  = "Advanced IoT reading schema with enum & range constraints"
  content_type = "application/json"

  schema = jsonencode({
    type     = "object",
    required = ["meter_id", "timestamp", "reading_value", "unit", "meter_type"],
    properties = {
      meter_id = {
        type        = "string",
        pattern     = "^[A-Z0-9_-]{2,20}$",
        description = "Unique meter ID (A–Z, 0–9, dash/underscore)"
      },
      timestamp = {
        type        = "string",
        format      = "date-time",
        description = "ISO-8601 timestamp of measurement"
      },
      reading_value = {
        type        = "number",
        multipleOf  = 0.000001,
        minimum     = 0,
        maximum     = 10000,
        description = "Measured value (0–10 000)"
      },
      unit = {
        type        = "string",
        enum        = ["kWh", "Wh", "V", "A"],
        description = "Measurement unit"
      },
      meter_type = {
        type        = "string",
        enum        = ["SMART_METER", "SOLAR_INVERTER", "CHARGER"],
        description = "Device category"
      }
    },
    additionalProperties = false
  })
}