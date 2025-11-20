module "aurora" {
  source = "./modules/aurora"

  vpc_id                   = module.network.vpc_id
  private_subnet_ids       = module.network.private_subnet_ids
  lambda_security_group_id = module.lambda.lambda_security_group_id
  resource_name_prefix     = var.resource_name_prefix

  aurora_engine                = var.aurora_engine
  aurora_engine_version        = var.aurora_engine_version
  aurora_port                  = var.aurora_port
  aurora_database_name         = var.aurora_database_name
  aurora_master_username       = var.aurora_master_username
  aurora_min_capacity          = var.aurora_min_capacity
  aurora_max_capacity          = var.aurora_max_capacity
  aurora_backup_retention_days = var.aurora_backup_retention_days
  aurora_deletion_protection   = var.aurora_deletion_protection
  aurora_skip_final_snapshot   = var.aurora_skip_final_snapshot
}
