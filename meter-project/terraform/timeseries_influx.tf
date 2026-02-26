module "timeseries_influx" {
  source = "./modules/timeseries_influx"

  project_name                     = var.project_name
  vpc_id                           = module.network.vpc_id
  subnet_ids                       = module.network.private_subnet_ids
  organization                     = var.influxdb_organization
  bucket_name                      = var.influx_hot_bucket_name != null ? var.influx_hot_bucket_name : (var.influxdb_bucket_name != null ? var.influxdb_bucket_name : "${var.project_name}-influxdb-bucket")
  db_name                          = "${var.project_name}-influxdb"
  db_instance_type                 = var.influxdb_instance_class
  allocated_storage                = var.influxdb_allocated_storage_gb
  ingress_security_group_ids       = [module.network.lambda_sg_id]
  ingress_cidr_blocks              = var.influxdb_ingress_cidr_blocks
  admin_password_length            = var.influxdb_admin_password_length
  publish_admin_credentials_to_ssm = var.publish_influxdb_admin_credentials_to_ssm
  admin_ssm_parameter_prefix       = var.influxdb_admin_ssm_parameter_prefix
  enable_bucket_tiering_automation = var.enable_influx_bucket_tiering_automation
  hot_bucket_name                  = var.influx_hot_bucket_name != null ? var.influx_hot_bucket_name : (var.influxdb_bucket_name != null ? var.influxdb_bucket_name : "${var.project_name}-influxdb-bucket")
  hot_bucket_retention_hours       = var.influx_hot_retention_hours
  cold_bucket_name                 = var.influx_cold_bucket_name != null ? var.influx_cold_bucket_name : "${var.project_name}-cold-15m"
  cold_bucket_retention_hours      = var.influx_cold_retention_hours
  admin_token_ssm_parameter_name   = var.influx_admin_token_ssm_parameter_name
}
