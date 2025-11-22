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
    security_groups = [var.lambda_security_group_id, aws_security_group.aurora_proxy.id]
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

resource "aws_security_group" "aurora_proxy" {
  name        = "${var.resource_name_prefix}-aurora-proxy-sg"
  description = "Allows Lambda to connect to RDS Proxy"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Lambda access to RDS Proxy"
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
    Name = "${var.resource_name_prefix}-aurora-proxy-sg"
  }
}

resource "aws_iam_role" "aurora_proxy" {
  name = "${var.resource_name_prefix}-aurora-proxy-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "aurora_proxy" {
  name = "${var.resource_name_prefix}-aurora-proxy-policy"
  role = aws_iam_role.aurora_proxy.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = aws_secretsmanager_secret.credentials.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"],
        Resource = "*"
      }
    ]
  })
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
  enable_http_endpoint         = false
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

resource "aws_db_proxy" "this" {
  name                   = "${var.resource_name_prefix}-aurora-proxy"
  debug_logging          = false
  engine_family          = "MYSQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.aurora_proxy.arn
  vpc_security_group_ids = [aws_security_group.aurora_proxy.id]
  vpc_subnet_ids         = var.private_subnet_ids

  auth {
    secret_arn = aws_secretsmanager_secret.credentials.arn
    iam_auth   = "DISABLED"
  }
}

resource "aws_db_proxy_default_target_group" "this" {
  db_proxy_name = aws_db_proxy.this.name

  connection_pool_config {
    connection_borrow_timeout    = 120
    max_connections_percent      = 90
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "cluster" {
  db_proxy_name         = aws_db_proxy.this.name
  target_group_name     = aws_db_proxy_default_target_group.this.name
  db_cluster_identifier = aws_rds_cluster.this.id
}
