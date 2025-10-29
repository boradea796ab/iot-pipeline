output "api_base_url" {
  value       = aws_api_gateway_deployment.iot_deploy.invoke_url
  description = "Public base URL of the Hello API Gateway"
}

output "api_key_device_m1" {
  value       = aws_api_gateway_api_key.device_m1.value
  description = "API key for device M1"
  sensitive   = true
}