resource "aws_grafana_workspace" "this" {
  name                     = local.grafana_name
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"

  data_sources = ["CLOUDWATCH"]
  role_arn     = aws_iam_role.grafana_service_role.arn
}
