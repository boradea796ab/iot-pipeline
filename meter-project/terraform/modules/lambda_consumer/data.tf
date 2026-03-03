data "archive_file" "iot_consumer" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = var.lambda_zip_path
}

data "aws_ssm_parameter" "influxdb_write_url" {
  name = var.influxdb_write_url_ssm_parameter
}

data "aws_ssm_parameter" "influxdb_token" {
  name            = var.influxdb_token_ssm_parameter
  with_decryption = true
}
