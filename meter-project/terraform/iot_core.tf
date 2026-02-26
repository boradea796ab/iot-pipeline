module "iot_core" {
  source = "./modules/iot_core"

  project_name         = var.project_name
  sim_meter_thing_name = var.sim_meter_thing_name
  certs_output_dir     = "${path.root}/../simulator/certs"
  kinesis_stream_name  = module.streaming.kinesis_stream_name
  kinesis_stream_arn   = module.streaming.kinesis_stream_arn
}
