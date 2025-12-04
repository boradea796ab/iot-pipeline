resource "aws_timestreaminfluxdb_db_instance" "meterdb" {

  organization = "VCC"
  bucket  = "${var.project_name}-influxdb-bucket"
  name = "${var.project_name}-influxdb"

  # Select a small instance since this is a lab/project
  db_instance_type = "db.influx.medium"

  # Storage size (GB)
  allocated_storage = 20

  username = "admin"
  password = random_password.master.result

  vpc_subnet_ids = values(aws_subnet.private)[*].id
  vpc_security_group_ids = [aws_security_group.influxdb_sg.id]

  tags = {
    Project = var.project_name
    Type    = "timestream-influxdb"
  }
}

resource "random_password" "master" {
  length  = 20
  special = false
  upper   = true
  numeric = true
}

