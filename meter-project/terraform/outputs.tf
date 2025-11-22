output "api_base_url" {
  value = module.api_gateway.api_base_url
}

output "sqs_url" {
  value = module.sqs.sqs_url
}

output "sqs_arn" {
  value = module.sqs.sqs_arn
}

output "api_key_device_m1" {
  value     = module.api_gateway.api_key_device_m1
  sensitive = true
}

output "dlq_arn" {
  value = module.sqs.dlq_sqs_arn
}

output "idempotency_table_name" {
  value = module.idempotency_table.table_name
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "lambda_security_group_id" {
  value = module.lambda.lambda_security_group_id
}

output "aurora_security_group_id" {
  value = module.aurora.aurora_security_group_id
}

output "aurora_cluster_endpoint" {
  value = module.aurora.aurora_cluster_endpoint
}

output "aurora_reader_endpoint" {
  value = module.aurora.aurora_reader_endpoint
}

output "aurora_secret_arn" {
  value = module.aurora.aurora_secret_arn
}

output "aurora_cluster_id" {
  value = module.aurora.aurora_cluster_id
}

output "aurora_proxy_endpoint" {
  value = module.aurora.db_proxy_endpoint
}

output "vpc_endpoint_security_group_id" {
  value = aws_security_group.vpc_endpoints.id
}

output "dynamodb_vpc_endpoint_id" {
  value = aws_vpc_endpoint.dynamodb.id
}

output "interface_vpc_endpoint_ids" {
  value = { for name, endpoint in aws_vpc_endpoint.interface : name => endpoint.id }
}
