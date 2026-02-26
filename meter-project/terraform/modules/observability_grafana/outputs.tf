output "grafana_workspace_id" {
  description = "Managed Grafana workspace ID."
  value       = aws_grafana_workspace.this.id
}

output "grafana_workspace_endpoint" {
  description = "Managed Grafana workspace endpoint."
  value       = aws_grafana_workspace.this.endpoint
}
