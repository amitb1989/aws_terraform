locals {
  tags = merge({
    Project     = "eks-ha-dr"
    Owner       = "platform-team"
    Environment = var.env
    ManagedBy   = "terraform"
  }, var.extra_tags)
}

module "network" {
  source               = "./modules/network"
  name                 = "${var.env}-core"
  cidr_block           = var.vpc_cidr
  az_count             = 2
  public_subnet_cidrs  = var.public_subnets
  private_subnet_cidrs = var.private_subnets
  enable_nat           = true
  tags                 = local.tags
}

output "vpc_id" { value = module.network.vpc_id }