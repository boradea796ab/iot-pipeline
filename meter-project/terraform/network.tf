module "network" {
  source = "./modules/network"

  aws_region           = var.aws_region
  project_name         = var.project_name
  name_prefix          = var.name_prefix
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
}
