module "eks" {
  source              = "./modules/eks"
  name                = "${var.env}-eks"
  region              = var.region
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  public_subnet_ids   = module.network.public_subnet_ids
  cluster_version     = "1.29"
  node_instance_types = ["t3.large"]
  desired_size        = 3
  min_size            = 2
  max_size            = 6
  tags                = local.tags
  #ebs_csi_irsa_role_arn = module.irsa_ebs.iam_role_arn
  #admin_role_arn = aws_iam_role.eks_admin.arn
  admin_role_arn = var.admin_role_arn
}