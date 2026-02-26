module "streaming" {
  source = "./modules/streaming"

  project_name            = var.project_name
  kinesis_shard_count     = var.kinesis_shard_count
  kinesis_retention_hours = var.kinesis_retention_hours
}
