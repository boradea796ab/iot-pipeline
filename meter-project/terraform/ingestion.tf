module "ingestion" {
  source = "./modules/ingestion"

  project_name         = var.project_name
  sim_meter_thing_name = var.sim_meter_thing_name
  certs_output_dir     = "${path.root}/../simulator/certs"
}
