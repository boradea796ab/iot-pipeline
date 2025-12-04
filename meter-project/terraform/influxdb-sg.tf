resource "aws_security_group" "influxdb_sg" {
  name        = "${var.project_name}-influxdb-sg"
  description = "Security group for Timestream for InfluxDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow inbound HTTP Line Protocol (InfluxDB port 8086)"
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]   # Flink app must run in same VPC
  }

  ingress {
  description = "Allow Flink app to send Line Protocol to InfluxDB"
  from_port   = 8086
  to_port     = 8086
  protocol    = "tcp"
  security_groups = [
    aws_security_group.flink_sg.id
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
