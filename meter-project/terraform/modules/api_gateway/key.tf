############################################################
# 🔐  Commit 6 — API Keys + Usage Plan (per client)
############################################################

# ----------------------------------------------------------
# 1️⃣  API Key — e.g. one device/client
# ----------------------------------------------------------
resource "aws_api_gateway_api_key" "device_m1" {
  name        = "device-m1"
  description = "API key for IoT device M001"
  enabled     = true
  value       = "m1-${random_string.key_suffix.result}"
}

# Generate random suffix so you don't hard-code keys
resource "random_string" "key_suffix" {
  length  = 40
  special = false
  upper   = false
}

# ----------------------------------------------------------
# 2️⃣  Usage Plan — rate & burst limits
# ----------------------------------------------------------
resource "aws_api_gateway_usage_plan" "iot_usage_plan" {
  name        = "iot-usage-plan"
  description = "Usage plan for IoT ingestion clients"

  throttle_settings {
    burst_limit = 200 # allow short spikes slightly above steady state
    rate_limit  = 200 # steady-state requests per second
  }

  quota_settings {
    limit  = 1000000 # total requests per day
    period = "DAY"
  }

  api_stages {
    api_id = aws_api_gateway_rest_api.iot_api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }
}

# ----------------------------------------------------------
# 3️⃣  Attach key → usage plan
# ----------------------------------------------------------
resource "aws_api_gateway_usage_plan_key" "device_m1_key" {
  key_id        = aws_api_gateway_api_key.device_m1.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.iot_usage_plan.id
}

# ----------------------------------------------------------
# 4️⃣  Require API key on /ingest method
# ----------------------------------------------------------
resource "aws_api_gateway_method_settings" "require_key_ingest" {
  rest_api_id = aws_api_gateway_rest_api.iot_api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "/ingest/POST"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false
    throttling_burst_limit = 55
    throttling_rate_limit  = 50
  }

  depends_on = [
    aws_api_gateway_method.ingest_post,
    aws_api_gateway_stage.prod
  ]
}

# Update the method itself to require a key (inside apigw.tf)
# Example:
# resource "aws_api_gateway_method" "ingest_post" {
#   ...
#   api_key_required = true
# }
