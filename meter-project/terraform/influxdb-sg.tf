resource "aws_security_group" "influxdb_sg" {
  name        = "${var.project_name}-influxdb-sg"
  description = "Security group for Timestream for InfluxDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow Lambda consumer to write Line Protocol to InfluxDB"
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    security_groups = [
      aws_security_group.lambda_sg.id
    ]
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
