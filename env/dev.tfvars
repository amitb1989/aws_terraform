region          = "ap-south-1"
env             = "dev"
vpc_cidr        = "10.0.0.0/16"
public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
extra_tags = { CostCenter = "dev-plat" }
admin_role_arn = "arn:aws:iam::888696596070:role/eks-admin-role"
