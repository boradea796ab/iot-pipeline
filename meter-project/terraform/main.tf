terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "api_gateway" {
  source               = "./modules/api_gateway"
  api_name             = "iot-ingestion-api"
  description          = "HMAC-based Lambda Authorizer"
  stage_name           = "prod"
  force_redeploy_token = "api-validator-redeploy-06"

  queue_name                     = module.sqs.sqs_name
  device_secret_parameter_prefix = var.device_secret_parameter_prefix
  device_secret_parameters = {
    M001 = "/iot/device/M001/secret"
    M002 = "/iot/device/M002/secret"
  }
}

module "sqs" {
  source     = "./modules/sqs"
  queue_name = "hellow_queue"
}

module "idempotency_table" {
  source     = "./modules/dynamodb"
  table_name = var.idempotency_table_name
}

module "network" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  name_prefix          = var.resource_name_prefix
}

module "lambda" {
  source                    = "./modules/lambda_consumer"
  sqs_arn                   = module.sqs.sqs_arn
  dlq_sqs_arn               = module.sqs.dlq_sqs_arn
  dlq_id                    = module.sqs.dlq_id
  idempotency_table         = module.idempotency_table.table_name
  idempotency_table_arn     = module.idempotency_table.table_arn
  payload_retention_seconds = var.idempotency_payload_ttl_seconds
  vpc_id                    = module.network.vpc_id
  resource_name_prefix      = var.resource_name_prefix
  private_subnet_ids        = module.network.private_subnet_ids
  secretsmanager_aurora_arn = module.aurora.aurora_secret_arn
  readings_table_name       = var.readings_table_name
}
