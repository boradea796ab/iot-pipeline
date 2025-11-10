data "archive_file" "dlq_processor" {
  type        = "zip"
  source_file = "${path.module}/lambda_dlq_processor.py"
  output_path = "${path.module}/lambda_dlq_processor.zip"
}
