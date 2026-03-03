resource "random_password" "master" {
  length  = var.admin_password_length
  special = false
  upper   = true
  numeric = true
}

resource "aws_ssm_parameter" "admin_username" {
  count = var.publish_admin_credentials_to_ssm ? 1 : 0

  name  = "${var.admin_ssm_parameter_prefix}/username"
  type  = "SecureString"
  value = var.admin_username
}

resource "aws_ssm_parameter" "admin_password" {
  count = var.publish_admin_credentials_to_ssm ? 1 : 0

  name  = "${var.admin_ssm_parameter_prefix}/password"
  type  = "SecureString"
  value = random_password.master.result
}
