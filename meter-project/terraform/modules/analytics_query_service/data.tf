data "archive_file" "analytics_query" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = var.lambda_zip_path
}

data "aws_ssm_parameter" "influxdb_query_url" {
  name = var.influxdb_query_url_ssm_parameter
}

data "aws_ssm_parameter" "influxdb_read_token" {
  name            = var.influxdb_read_token_ssm_parameter
  with_decryption = true
}
