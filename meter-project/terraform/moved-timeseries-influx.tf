moved {
  from = aws_timestreaminfluxdb_db_instance.meterdb
  to   = module.timeseries_influx.aws_timestreaminfluxdb_db_instance.meterdb
}

moved {
  from = random_password.master
  to   = module.timeseries_influx.random_password.master
}

moved {
  from = module.network.aws_security_group.influxdb_sg
  to   = module.timeseries_influx.aws_security_group.influxdb
}
