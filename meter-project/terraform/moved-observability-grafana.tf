moved {
  from = aws_iam_role.grafana_service_role
  to   = module.observability_grafana.aws_iam_role.grafana_service_role
}

moved {
  from = aws_iam_role_policy.grafana_cloudwatch_read
  to   = module.observability_grafana.aws_iam_role_policy.grafana_cloudwatch_read
}

moved {
  from = aws_grafana_workspace.this
  to   = module.observability_grafana.aws_grafana_workspace.this
}
