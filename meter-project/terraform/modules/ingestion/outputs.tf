output "iot_endpoint" {
  description = "AWS IoT Core data endpoint (MQTT over TLS)."
  value       = data.aws_iot_endpoint.data.endpoint_address
}

output "sim_thing_name" {
  description = "Simulator thing name."
  value       = aws_iot_thing.sim_meter.name
}

output "kinesis_stream_name" {
  description = "Kinesis stream name for IoT telemetry."
  value       = aws_kinesis_stream.iot_telemetry.name
}

output "kinesis_stream_arn" {
  description = "Kinesis stream ARN for IoT telemetry."
  value       = aws_kinesis_stream.iot_telemetry.arn
}

output "iot_rules_role_arn" {
  description = "IAM role ARN assumed by IoT Rules."
  value       = aws_iam_role.iot_rules_role.arn
}
