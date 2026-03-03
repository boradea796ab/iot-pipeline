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

output "analytics_query_timeseries_url" {
  description = "Timeseries query endpoint URL for analytics query service."
  value       = module.analytics_query_service.timeseries_query_url
}

output "analytics_query_statistics_url" {
  description = "Statistics query endpoint URL for analytics query service."
  value       = module.analytics_query_service.statistics_query_url
}

output "grafana_workspace_id" {
  description = "Grafana workspace ID."
  value       = module.observability_grafana.grafana_workspace_id
}

output "grafana_workspace_endpoint" {
  description = "Grafana workspace endpoint."
  value       = module.observability_grafana.grafana_workspace_endpoint
}

output "grafana_influx_datasource_payload" {
  description = "Payload to create/update Grafana InfluxDB data source."
  value       = module.observability_grafana.influx_datasource_payload
}

output "grafana_baseline_dashboard_files" {
  description = "Baseline Grafana dashboard JSON files bundled in the module."
  value       = module.observability_grafana.baseline_dashboard_files
}
