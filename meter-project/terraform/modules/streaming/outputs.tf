output "kinesis_stream_name" {
  description = "Kinesis stream name for IoT telemetry."
  value       = aws_kinesis_stream.iot_telemetry.name
}

output "kinesis_stream_arn" {
  description = "Kinesis stream ARN for IoT telemetry."
  value       = aws_kinesis_stream.iot_telemetry.arn
}
