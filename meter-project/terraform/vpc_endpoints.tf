locals {
  interface_endpoints = {
    sqs = {
      service = "sqs"
    }
    logs = {
      service = "logs"
    }
    sts = {
      service = "sts"
    }
    secretsmanager = {
      service = "secretsmanager"
    }
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.resource_name_prefix}-vpc-endpoints-sg"
  description = "Restrict VPC interface endpoints to Lambda SG"
  vpc_id      = module.network.vpc_id

  ingress {
    description     = "Lambda to endpoint"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [module.lambda.lambda_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_name_prefix}-vpc-endpoints-sg"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.network.vpc_id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [module.network.private_route_table_id]

  tags = {
    Name = "${var.resource_name_prefix}-dynamodb-endpoint"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = module.network.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value.service}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.network.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.resource_name_prefix}-${each.key}-endpoint"
  }
}
