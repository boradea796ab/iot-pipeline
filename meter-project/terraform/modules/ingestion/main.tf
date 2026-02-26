locals {
  # Terraform version in this stack lacks regexreplace, so just swap hyphens
  iot_rule_name_prefix = replace(var.project_name, "-", "_")
}

resource "aws_iot_thing" "sim_meter" {
  name = var.sim_meter_thing_name

  attributes = {
    project = var.project_name
    type    = "simulator"
  }
}

resource "aws_iot_certificate" "sim_meter_cert" {
  active = true

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_iot_policy" "sim_meter_policy" {
  name = "${var.project_name}-sim-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iot:Connect",
          "iot:Publish",
          "iot:Receive",
          "iot:Subscribe"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iot_policy_attachment" "sim_meter_policy_attach" {
  policy = aws_iot_policy.sim_meter_policy.name
  target = aws_iot_certificate.sim_meter_cert.arn

  depends_on = [
    aws_iot_certificate.sim_meter_cert,
    aws_iot_policy.sim_meter_policy
  ]
}

resource "aws_iot_thing_principal_attachment" "sim_meter_thing_attach" {
  thing     = aws_iot_thing.sim_meter.name
  principal = aws_iot_certificate.sim_meter_cert.arn

  depends_on = [
    aws_iot_certificate.sim_meter_cert,
    aws_iot_thing.sim_meter
  ]
}

data "aws_iot_endpoint" "data" {
  endpoint_type = "iot:Data-ATS"
}

resource "local_file" "sim_cert_pem" {
  filename = "${var.certs_output_dir}/device_certificate.pem"
  content  = aws_iot_certificate.sim_meter_cert.certificate_pem
}

resource "local_file" "sim_private_key" {
  filename = "${var.certs_output_dir}/private_key.pem"
  content  = aws_iot_certificate.sim_meter_cert.private_key
}

resource "local_file" "sim_public_key" {
  filename = "${var.certs_output_dir}/public_key.pem"
  content  = aws_iot_certificate.sim_meter_cert.public_key
}

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

resource "aws_iam_role" "iot_rules_role" {
  name = "${var.project_name}-iot-rules-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "iot.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "iot_rules_policy" {
  name = "${var.project_name}-iot-rules-policy"
  role = aws_iam_role.iot_rules_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = aws_kinesis_stream.iot_telemetry.arn
      }
    ]
  })
}

resource "aws_iot_topic_rule" "meters_to_kinesis" {
  name        = "${local.iot_rule_name_prefix}_meters_rule"
  enabled     = true
  sql         = "SELECT * FROM 'meters/+/readings'"
  sql_version = "2016-03-23"

  kinesis {
    role_arn      = aws_iam_role.iot_rules_role.arn
    stream_name   = aws_kinesis_stream.iot_telemetry.name
    partition_key = "topic()"
  }
}
