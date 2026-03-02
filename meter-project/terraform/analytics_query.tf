module "analytics_query_service" {
  source = "./modules/analytics_query_service"

  project_name              = var.project_name
  aws_region                = var.aws_region
  private_subnet_ids        = module.network.private_subnet_ids
  lambda_security_group_ids = [module.network.lambda_sg_id]

  lambda_source_dir = "${path.root}/lambda_analytics_source"
  lambda_zip_path   = "${path.root}/analytics_query_service.zip"

  lambda_timeout_seconds      = var.analytics_query_lambda_timeout_seconds
  lambda_memory_mb            = var.analytics_query_lambda_memory_mb
  lambda_reserved_concurrency = var.analytics_query_lambda_reserved_concurrency
  log_retention_days          = var.analytics_query_log_retention_days
  api_stage_name              = var.analytics_query_api_stage_name

  influx_org                        = var.influxdb_organization
  influx_hot_bucket_name            = module.timeseries_influx.influx_hot_bucket_name
  influx_cold_bucket_name           = module.timeseries_influx.influx_cold_bucket_name
  influxdb_query_url_ssm_parameter  = var.analytics_query_influxdb_query_url_ssm_parameter
  influxdb_read_token_ssm_parameter = var.analytics_query_influxdb_read_token_ssm_parameter
  hot_retention_days                = var.analytics_query_hot_retention_days
  max_lookback_days                 = var.analytics_query_max_lookback_days
  max_series_limit                  = var.analytics_query_max_series_limit
  max_meter_ids                     = var.analytics_query_max_meter_ids
  query_timeout_seconds             = var.analytics_query_influx_timeout_seconds
  invoke_role_arns                  = var.analytics_query_invoke_role_arns
  metrics_namespace                 = var.analytics_query_metrics_namespace
}
