output "iot_endpoint" {
  description = "AWS IoT Core data endpoint (MQTT over TLS)"
  value       = data.aws_iot_endpoint.data.endpoint_address
}

output "sim_thing_name" {
  value = aws_iot_thing.sim_meter.name
}

output "sim_cert_files_path" {
  value = "../simulator/certs"
}
