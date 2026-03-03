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
