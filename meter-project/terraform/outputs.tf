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
