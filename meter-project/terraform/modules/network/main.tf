resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnet_configs

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-private-${each.key}"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnet_configs

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-public-${each.key}"
  })
}

resource "aws_internet_gateway" "this" {
  count = local.create_public_resources ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = "${var.project_name}-lambda-sg"
  description = "SG for Kinesis Lambda consumer"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
    Type    = "lambda"
  }
}
