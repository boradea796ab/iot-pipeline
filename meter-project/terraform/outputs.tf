output "api_base_url" {
  value = module.api_gateway.api_base_url
}

output "sqs_url" {
  value       = module.sqs.sqs_url
}

output "sqs_arn" {
  value       = module.sqs.sqs_arn
}