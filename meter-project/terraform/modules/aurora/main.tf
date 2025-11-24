resource "aws_db_subnet_group" "this" {
  name       = "${var.resource_name_prefix}-aurora-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.resource_name_prefix}-aurora-subnets"
  }
}

resource "aws_security_group" "aurora" {
  name        = "${var.resource_name_prefix}-aurora-sg"
  description = "Restricts Aurora access to Lambda"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Lambda access to Aurora"
    from_port       = var.aurora_port
    to_port         = var.aurora_port
    protocol        = "tcp"
    security_groups = [var.lambda_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_name_prefix}-aurora-sg"
  }
}

resource "random_password" "master" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>?:"
}

resource "aws_secretsmanager_secret" "credentials" {
  name_prefix = "${var.resource_name_prefix}-aurora-credentials-"

  tags = {
    Name = "${var.resource_name_prefix}-aurora-credentials"
  }
}

resource "aws_rds_cluster" "this" {
  cluster_identifier           = "${var.resource_name_prefix}-aurora-cluster"
  engine                       = var.aurora_engine
  engine_version               = var.aurora_engine_version != "" ? var.aurora_engine_version : null
  database_name                = var.aurora_database_name
  master_username              = var.aurora_master_username
  master_password              = random_password.master.result
  port                         = var.aurora_port
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.aurora.id]
  storage_encrypted            = true
  backup_retention_period      = var.aurora_backup_retention_days
  deletion_protection          = var.aurora_deletion_protection
  skip_final_snapshot          = var.aurora_skip_final_snapshot
  apply_immediately            = true
  copy_tags_to_snapshot        = true
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:30-sun:05:30"
  enable_http_endpoint         = true
  # for external access- do not enable for production
  # enable_http_endpoint = true

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }
}

resource "aws_rds_cluster_instance" "this" {
  count                = 1
  identifier           = "${var.resource_name_prefix}-aurora-cluster-${count.index + 1}"
  cluster_identifier   = aws_rds_cluster.this.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.this.engine
  engine_version       = aws_rds_cluster.this.engine_version
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.this.name
}

resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id = aws_secretsmanager_secret.credentials.id
  secret_string = jsonencode({
    username    = var.aurora_master_username
    password    = random_password.master.result
    engine      = var.aurora_engine
    port        = var.aurora_port
    database    = var.aurora_database_name
    host        = aws_rds_cluster.this.endpoint
    reader_host = aws_rds_cluster.this.reader_endpoint
    cluster_arn = aws_rds_cluster.this.arn
  })

  depends_on = [aws_rds_cluster.this]
}
