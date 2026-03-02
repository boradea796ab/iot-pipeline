output "grafana_workspace_id" {
  description = "Managed Grafana workspace ID."
  value       = aws_grafana_workspace.this.id
}

output "grafana_workspace_endpoint" {
  description = "Managed Grafana workspace endpoint."
  value       = aws_grafana_workspace.this.endpoint
}

output "influx_datasource_payload" {
  description = "Grafana datasource provisioning payload for InfluxDB (manual API/UI import)."
  value       = local.influx_datasource_payload
}

output "baseline_dashboard_files" {
  description = "Baseline dashboard JSON files to import into Grafana."
  value = [
    "${path.module}/dashboards/realtime_live_overview.json",
    "${path.module}/dashboards/historical_analytics_overview.json",
  ]
}
