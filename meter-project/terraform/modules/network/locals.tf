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
