data "archive_file" "iot_consumer" {
  type        = "zip"
  source_dir  = "${path.module}/build/iot_consumer"
  output_path = "${path.module}/lambda_consumer.zip"
}
