resource "aws_security_group" "influxdb" {
  name        = "${var.project_name}-influxdb-sg"
  description = "Security group for Timestream for InfluxDB"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_security_group_ids
    content {
      description     = "Allow Lambda consumer to write Line Protocol to InfluxDB"
      from_port       = var.influxdb_port
      to_port         = var.influxdb_port
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = var.ingress_cidr_blocks
    content {
      description = "Allow configured CIDR blocks to access InfluxDB"
      from_port   = var.influxdb_port
      to_port     = var.influxdb_port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
  }
}
