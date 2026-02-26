module "lambda_consumer" {
  source = "./modules/lambda_consumer"

  project_name              = var.project_name
  aws_region                = var.aws_region
  kinesis_stream_arn        = module.streaming.kinesis_stream_arn
  private_subnet_ids        = module.network.private_subnet_ids
  lambda_security_group_ids = [module.network.lambda_sg_id]
  lambda_source_dir         = "${path.root}/lambda_source"
  lambda_zip_path           = "${path.root}/lambda_consumer.zip"
}
