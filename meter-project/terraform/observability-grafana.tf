module "observability_grafana" {
  source = "./modules/observability_grafana"

  project_name            = var.project_name
  name_prefix             = var.name_prefix
  grafana_admin_role_arns = var.grafana_admin_role_arns
  influx_org              = var.influxdb_organization
  influx_query_url        = "https://${module.timeseries_influx.influxdb_endpoint}:${module.timeseries_influx.influxdb_port}"
  influx_default_bucket   = module.timeseries_influx.influx_hot_bucket_name
}
