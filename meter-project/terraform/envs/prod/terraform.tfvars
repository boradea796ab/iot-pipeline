project_name         = "smart-meter-iot"
name_prefix          = "network"
sim_meter_thing_name = "sim-meter-001"
vpc_cidr             = "10.0.0.0/16"

private_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24",
]

# Timeseries (InfluxDB) sizing defaults for current project.
influxdb_instance_class       = "db.influx.medium"
influxdb_allocated_storage_gb = 20

# Streaming defaults for current project.
kinesis_shard_count     = 1
kinesis_retention_hours = 24
