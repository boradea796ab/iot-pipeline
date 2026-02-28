resource "random_password" "master" {
  length  = var.admin_password_length
  special = false
  upper   = true
  numeric = true
}

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

resource "aws_timestreaminfluxdb_db_instance" "meterdb" {
  organization = var.organization
  bucket       = var.hot_bucket_name
  name         = var.db_name

  db_instance_type  = var.db_instance_type
  allocated_storage = var.allocated_storage

  username = var.admin_username
  password = random_password.master.result

  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = [aws_security_group.influxdb.id]

  tags = {
    Project = var.project_name
    Type    = "timestream-influxdb"
  }
}

resource "aws_ssm_parameter" "admin_username" {
  count = var.publish_admin_credentials_to_ssm ? 1 : 0

  name  = "${var.admin_ssm_parameter_prefix}/username"
  type  = "SecureString"
  value = var.admin_username
}

resource "aws_ssm_parameter" "admin_password" {
  count = var.publish_admin_credentials_to_ssm ? 1 : 0

  name  = "${var.admin_ssm_parameter_prefix}/password"
  type  = "SecureString"
  value = random_password.master.result
}
