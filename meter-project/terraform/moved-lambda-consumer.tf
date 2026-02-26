moved {
  from = aws_iam_role.lambda_role
  to   = module.lambda_consumer.aws_iam_role.lambda_role
}

moved {
  from = aws_iam_role_policy.lambda_policy
  to   = module.lambda_consumer.aws_iam_role_policy.lambda_policy
}

moved {
  from = aws_lambda_function.kinesis_to_influx
  to   = module.lambda_consumer.aws_lambda_function.kinesis_to_influx
}

moved {
  from = aws_lambda_event_source_mapping.kinesis_trigger
  to   = module.lambda_consumer.aws_lambda_event_source_mapping.kinesis_trigger
}
