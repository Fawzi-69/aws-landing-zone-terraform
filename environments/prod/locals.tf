locals {
  default_tags = {
    Project   = var.project
    Env       = var.env
    Owner     = var.owner
    ManagedBy = "terraform"
  }

  # Carve three /20 subnets per tier out of the VPC /16 (one per AZ):
  #   tier offset 0 -> public, 3 -> private-app, 6 -> private-data.
  public_subnet_cidrs       = [for i in range(length(var.azs)) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_app_subnet_cidrs  = [for i in range(length(var.azs)) : cidrsubnet(var.vpc_cidr, 4, i + 3)]
  private_data_subnet_cidrs = [for i in range(length(var.azs)) : cidrsubnet(var.vpc_cidr, 4, i + 6)]
}
