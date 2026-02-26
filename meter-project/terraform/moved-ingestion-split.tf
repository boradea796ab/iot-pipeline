moved {
  from = module.ingestion.aws_iot_thing.sim_meter
  to   = module.iot_core.aws_iot_thing.sim_meter
}

moved {
  from = module.ingestion.aws_iot_certificate.sim_meter_cert
  to   = module.iot_core.aws_iot_certificate.sim_meter_cert
}

moved {
  from = module.ingestion.aws_iot_policy.sim_meter_policy
  to   = module.iot_core.aws_iot_policy.sim_meter_policy
}

moved {
  from = module.ingestion.aws_iot_policy_attachment.sim_meter_policy_attach
  to   = module.iot_core.aws_iot_policy_attachment.sim_meter_policy_attach
}

moved {
  from = module.ingestion.aws_iot_thing_principal_attachment.sim_meter_thing_attach
  to   = module.iot_core.aws_iot_thing_principal_attachment.sim_meter_thing_attach
}

moved {
  from = module.ingestion.local_file.sim_cert_pem
  to   = module.iot_core.local_file.sim_cert_pem
}

moved {
  from = module.ingestion.local_file.sim_private_key
  to   = module.iot_core.local_file.sim_private_key
}

moved {
  from = module.ingestion.local_file.sim_public_key
  to   = module.iot_core.local_file.sim_public_key
}

moved {
  from = module.ingestion.aws_iam_role.iot_rules_role
  to   = module.iot_core.aws_iam_role.iot_rules_role
}

moved {
  from = module.ingestion.aws_iam_role_policy.iot_rules_policy
  to   = module.iot_core.aws_iam_role_policy.iot_rules_policy
}

moved {
  from = module.ingestion.aws_iot_topic_rule.meters_to_kinesis
  to   = module.iot_core.aws_iot_topic_rule.meters_to_kinesis
}

moved {
  from = module.ingestion.aws_kinesis_stream.iot_telemetry
  to   = module.streaming.aws_kinesis_stream.iot_telemetry
}
