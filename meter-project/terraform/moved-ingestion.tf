moved {
  from = aws_iot_thing.sim_meter
  to   = module.ingestion.aws_iot_thing.sim_meter
}

moved {
  from = aws_iot_certificate.sim_meter_cert
  to   = module.ingestion.aws_iot_certificate.sim_meter_cert
}

moved {
  from = aws_iot_policy.sim_meter_policy
  to   = module.ingestion.aws_iot_policy.sim_meter_policy
}

moved {
  from = aws_iot_policy_attachment.sim_meter_policy_attach
  to   = module.ingestion.aws_iot_policy_attachment.sim_meter_policy_attach
}

moved {
  from = aws_iot_thing_principal_attachment.sim_meter_thing_attach
  to   = module.ingestion.aws_iot_thing_principal_attachment.sim_meter_thing_attach
}

moved {
  from = local_file.sim_cert_pem
  to   = module.ingestion.local_file.sim_cert_pem
}

moved {
  from = local_file.sim_private_key
  to   = module.ingestion.local_file.sim_private_key
}

moved {
  from = local_file.sim_public_key
  to   = module.ingestion.local_file.sim_public_key
}

moved {
  from = aws_kinesis_stream.iot_telemetry
  to   = module.ingestion.aws_kinesis_stream.iot_telemetry
}

moved {
  from = aws_iam_role.iot_rules_role
  to   = module.ingestion.aws_iam_role.iot_rules_role
}

moved {
  from = aws_iam_role_policy.iot_rules_policy
  to   = module.ingestion.aws_iam_role_policy.iot_rules_policy
}

moved {
  from = aws_iot_topic_rule.meters_to_kinesis
  to   = module.ingestion.aws_iot_topic_rule.meters_to_kinesis
}
