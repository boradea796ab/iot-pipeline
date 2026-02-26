resource "aws_kinesis_stream" "iot_telemetry" {
  name             = "${var.project_name}-telemetry"
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_hours

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Project = var.project_name
  }
}
