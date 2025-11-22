output "aurora_security_group_id" {
  value = aws_security_group.aurora.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.this.name
}

output "aurora_cluster_endpoint" {
  value = aws_rds_cluster.this.endpoint
}

output "aurora_reader_endpoint" {
  value = aws_rds_cluster.this.reader_endpoint
}

output "aurora_secret_arn" {
  value = aws_secretsmanager_secret.credentials.arn
}

output "aurora_cluster_id" {
  value = aws_rds_cluster.this.id
}

output "db_proxy_endpoint" {
  value = aws_db_proxy.this.endpoint
}

output "db_proxy_arn" {
  value = aws_db_proxy.this.arn
}

output "db_proxy_name" {
  value = aws_db_proxy.this.name
}
