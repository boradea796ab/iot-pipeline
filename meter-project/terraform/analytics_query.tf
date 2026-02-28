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
}
