output "iot_endpoint" {
  description = "AWS IoT Core data endpoint (MQTT over TLS)"
  value       = module.iot_core.iot_endpoint
}

output "sim_thing_name" {
  value = module.iot_core.sim_thing_name
}

output "sim_cert_files_path" {
  value = "../simulator/certs"
}


output "kinesis_stream_name" {
  value       = module.streaming.kinesis_stream_name
  description = "IoT telemetry Kinesis stream"
}

output "influxdb_endpoint" {
  value = module.timeseries_influx.influxdb_endpoint
}

output "influxdb_port" {
  value = module.timeseries_influx.influxdb_port
}
