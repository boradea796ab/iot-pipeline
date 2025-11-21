data "archive_file" "dlq_processor" {
  type        = "zip"
  source_dir  = "${path.module}/build/dlq_processor"
  output_path = "${path.module}/lambda_dlq_processor.zip"
}
