resource "aws_kinesis_stream" "iot_telemetry" {
  name             = "${var.project_name}-telemetry"
  shard_count      = 1              # start with 1, we can scale later
  retention_period = 24             # hours, good enough for now

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Project = var.project_name
  }
}
