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


output "kinesis_stream_name" {
  value       = aws_kinesis_stream.iot_telemetry.name
  description = "IoT telemetry Kinesis stream"
}

output "influxdb_endpoint" {
  value = aws_timestreaminfluxdb_db_instance.meterdb.endpoint
}

output "influxdb_port" {
  value = aws_timestreaminfluxdb_db_instance.meterdb.port
}

