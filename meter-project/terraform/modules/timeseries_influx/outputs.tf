output "influxdb_sg_id" {
  description = "Security group ID attached to the InfluxDB instance."
  value       = aws_security_group.influxdb.id
}

output "influxdb_endpoint" {
  description = "InfluxDB endpoint."
  value       = aws_timestreaminfluxdb_db_instance.meterdb.endpoint
}

output "influxdb_port" {
  description = "InfluxDB port."
  value       = aws_timestreaminfluxdb_db_instance.meterdb.port
}

output "influxdb_name" {
  description = "InfluxDB instance name."
  value       = aws_timestreaminfluxdb_db_instance.meterdb.name
}

output "influxdb_bucket" {
  description = "InfluxDB bucket name."
  value       = var.hot_bucket_name
}

output "admin_username" {
  description = "InfluxDB admin username."
  value       = var.admin_username
}

output "admin_password" {
  description = "Generated InfluxDB admin password."
  value       = random_password.master.result
  sensitive   = true
}

output "influx_hot_bucket_name" {
  description = "Hot bucket name for recent raw data."
  value       = var.hot_bucket_name
}

output "influx_cold_bucket_name" {
  description = "Cold bucket name for downsampled historical data."
  value       = var.cold_bucket_name
}
