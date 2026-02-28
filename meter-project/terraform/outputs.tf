output "iot_endpoint" {
  description = "AWS IoT Core data endpoint (MQTT over TLS)"
  value       = module.iot_core.iot_endpoint
}

output "sim_thing_name" {
  value = module.iot_core.sim_thing_name
}

output "sim_cert_files_path" {
  value = "../simulator/certs"
}


output "kinesis_stream_name" {
  value       = module.streaming.kinesis_stream_name
  description = "IoT telemetry Kinesis stream"
}

output "influxdb_endpoint" {
  value = module.timeseries_influx.influxdb_endpoint
}

output "influxdb_port" {
  value = module.timeseries_influx.influxdb_port
}

output "analytics_query_lambda_function_name" {
  description = "Analytics query Lambda function name."
  value       = module.analytics_query_service.lambda_function_name
}

output "analytics_query_api_endpoint" {
  description = "Base endpoint of analytics query API Gateway HTTP API."
  value       = module.analytics_query_service.api_endpoint
}

output "analytics_query_health_url" {
  description = "Health endpoint URL for analytics query service."
  value       = module.analytics_query_service.health_url
}

output "analytics_query_stub_query_url" {
  description = "Stub query endpoint URL for analytics query service."
  value       = module.analytics_query_service.query_url
}
