resource "aws_iot_thing" "sim_meter" {
  name = var.sim_meter_thing_name

  attributes = {
    project = var.project_name
    type    = "simulator"
  }
}

# IoT certificate + key pair
resource "aws_iot_certificate" "sim_meter_cert" {
  active = true
}

# Basic IoT policy for simulator (you can tighten later)
data "aws_caller_identity" "current" {}

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

# Attach policy to certificate
resource "aws_iot_policy_attachment" "sim_meter_policy_attach" {
  policy = aws_iot_policy.sim_meter_policy.name
  target = aws_iot_certificate.sim_meter_cert.arn
}

# Attach certificate to thing
resource "aws_iot_thing_principal_attachment" "sim_meter_thing_attach" {
  thing     = aws_iot_thing.sim_meter.name
  principal = aws_iot_certificate.sim_meter_cert.arn
}

# Get IoT Core data endpoint (for MQTT over TLS)
data "aws_iot_endpoint" "data" {
  endpoint_type = "iot:Data-ATS"
}

# Dump certs/keys to local files for the simulator
resource "local_file" "sim_cert_pem" {
  filename = "${path.module}/../simulator/certs/device_certificate.pem"
  content  = aws_iot_certificate.sim_meter_cert.certificate_pem
}

resource "local_file" "sim_private_key" {
  filename = "${path.module}/../simulator/certs/private_key.pem"
  content  = aws_iot_certificate.sim_meter_cert.private_key
}

resource "local_file" "sim_public_key" {
  filename = "${path.module}/../simulator/certs/public_key.pem"
  content  = aws_iot_certificate.sim_meter_cert.public_key
}
