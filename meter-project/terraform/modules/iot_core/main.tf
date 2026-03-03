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

resource "aws_iot_topic_rule" "meters_to_kinesis" {
  name        = "${local.iot_rule_name_prefix}_meters_rule"
  enabled     = true
  sql         = "SELECT * FROM 'meters/+/readings'"
  sql_version = "2016-03-23"

  kinesis {
    role_arn      = aws_iam_role.iot_rules_role.arn
    stream_name   = var.kinesis_stream_name
    partition_key = "topic()"
  }
}
