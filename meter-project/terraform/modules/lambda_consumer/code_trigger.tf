data "archive_file" "iot_consumer" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"   # or source_dir for multiple files
  output_path = "${path.module}/lambda_consumer.zip"
}