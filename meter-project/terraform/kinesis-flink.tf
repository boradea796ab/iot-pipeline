resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # Read from Kinesis
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListStreams"
        ]
        Resource = aws_kinesis_stream.iot_telemetry.arn
      },

      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.flink_region}:*:*"
      },

      # VPC ENI permissions (REQUIRED)
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "iot_consumer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_source"
  output_path = "${path.module}/lambda_consumer.zip"
}

data "aws_ssm_parameter" "influxdb_write_url" {
  name = "/smart-meter/iot/influxdb/write-url"
}

data "aws_ssm_parameter" "influxdb_token" {
  name            = "/smart-meter/iot/influxdb/token"
  with_decryption = true
}

resource "aws_lambda_function" "kinesis_to_influx" {
  function_name    = "${var.project_name}-kinesis-to-influx"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.11"
  handler          = "kinesis2timestream.lambda_handler"
  timeout          = 60
  memory_size      = 512
  filename         = data.archive_file.iot_consumer.output_path
  source_code_hash = data.archive_file.iot_consumer.output_base64sha256


  vpc_config {
    subnet_ids         = module.network.private_subnet_ids
    security_group_ids = [module.network.lambda_sg_id]
  }

  environment {
    variables = {
      INFLUX_URL   = data.aws_ssm_parameter.influxdb_write_url.value
      INFLUX_TOKEN = data.aws_ssm_parameter.influxdb_token.value
    }
  }
}

resource "aws_lambda_event_source_mapping" "kinesis_trigger" {
  event_source_arn  = aws_kinesis_stream.iot_telemetry.arn
  function_name     = aws_lambda_function.kinesis_to_influx.arn
  starting_position = "LATEST"

  batch_size                         = 100
  maximum_batching_window_in_seconds = 5
}

variable "flink_app_name" {
  type    = string
  default = "smart-meter-iot-flink"
}

variable "flink_region" {
  type    = string
  default = "ap-northeast-1"
}
