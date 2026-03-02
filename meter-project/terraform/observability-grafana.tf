variable "grafana_admin_role_arns" {
  type        = list(string)
  description = "IAM role ARNs that should be Grafana workspace admins (usually your SSO roles)."
  default     = ["arn:aws:iam::808329257566:role/aws-reserved/sso.amazonaws.com/ap-northeast-1/AWSReservedSSO_GrafanaAdmin_53a8c239834e0009"]
}

module "observability_grafana" {
  source = "./modules/observability_grafana"

  project_name            = var.project_name
  name_prefix             = var.name_prefix
  grafana_admin_role_arns = var.grafana_admin_role_arns
  influx_org              = var.influxdb_organization
  influx_query_url        = "https://${module.timeseries_influx.influxdb_endpoint}:${module.timeseries_influx.influxdb_port}"
  influx_default_bucket   = module.timeseries_influx.influx_hot_bucket_name
}

output "grafana_workspace_id" {
  value = module.observability_grafana.grafana_workspace_id
}

output "grafana_workspace_endpoint" {
  value = module.observability_grafana.grafana_workspace_endpoint
}

output "grafana_influx_datasource_payload" {
  value = module.observability_grafana.influx_datasource_payload
}

output "grafana_baseline_dashboard_files" {
  value = module.observability_grafana.baseline_dashboard_files
}
