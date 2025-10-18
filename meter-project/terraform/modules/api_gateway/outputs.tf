output "api_base_url" {
  value = aws_api_gateway_deployment.hello_deploy.invoke_url
  description = "Public base URL of the Hello API Gateway"
}