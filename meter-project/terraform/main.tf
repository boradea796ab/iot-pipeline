terraform {
    required_version = ">= 1.6.0"
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = var.region
}

module "api_gateway" {
  source      = "./modules/api_gateway"
  api_name    = "iot-ingestion-api"
  description = "Mock API Gateway for /health endpoint"
  stage_name  = "prod"

  queue_arn       = module.sqs.sqs_arn
  queue_name      = module.sqs.sqs_name
  queue_url       = module.sqs.sqs_url
}

module "sqs" {
  source = "./modules/sqs"
  queue_name = "hellow_queue"
}