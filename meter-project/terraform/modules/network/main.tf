data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = data.aws_availability_zones.available.names

  private_subnet_configs = {
    for idx, cidr in var.private_subnet_cidrs : idx => {
      cidr = cidr
      az   = local.azs[idx % length(local.azs)]
    }
  }

  public_subnet_configs = {
    for idx, cidr in var.public_subnet_cidrs : idx => {
      cidr = cidr
      az   = local.azs[idx % length(local.azs)]
    }
  }

  create_public_resources = length(var.public_subnet_cidrs) > 0

  base_tags = {
    Project = var.project_name
  }
}

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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-private-rt"
  })
}

resource "aws_route_table" "public" {
  count = local.create_public_resources ? 1 : 0

  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  for_each = local.create_public_resources ? aws_subnet.public : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
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

resource "aws_security_group" "influxdb_sg" {
  name        = "${var.project_name}-influxdb-sg"
  description = "Security group for Timestream for InfluxDB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow Lambda consumer to write Line Protocol to InfluxDB"
    from_port   = 8086
    to_port     = 8086
    protocol    = "tcp"
    security_groups = [
      aws_security_group.lambda_sg.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
  }
}
