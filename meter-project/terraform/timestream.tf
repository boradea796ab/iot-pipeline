resource "aws_timestreamwrite_database" "meter_data" {
  database_name = "${var.project_name}_db"

  tags = {
    Project = var.project_name
  }
}

resource "aws_timestreamwrite_table" "raw_readings" {
  database_name = aws_timestreamwrite_database.meter_data.database_name
  table_name    = "raw_readings"

  retention_properties {
    memory_store_retention_period_in_hours   = 24   # hot data
    magnetic_store_retention_period_in_days  = 365  # 1 year history
  }

  tags = {
    Project = var.project_name
    Type    = "raw"
  }
}
