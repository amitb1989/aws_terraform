locals { cluster_name = var.name }

module "eks" {
  
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

# cluster_enabled_log_types = [
#     "api",
#     "audit",
#     "authenticator",
#     "controllerManager",
#     "scheduler"
#   ]

  eks_managed_node_groups = {
    default = {
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
      instance_types = var.node_instance_types
      subnets        = var.private_subnet_ids
      tags           = var.tags
      # 🔐 Add SSM perms to the node instance role
      iam_role_additional_policies = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }

  }

  cluster_addons = {
  coredns    = { most_recent = true }
  kube-proxy = { most_recent = true }
  vpc-cni    = { most_recent = true }

 

  }

  tags = var.tags

  
            


 
# Recommended: enable access entries (v20+)
  # modules/eks/main.tf
access_entries = {
  sso_admin = {
    principal_arn = var.admin_role_arn  # pass this string from root
    # Attach AmazonEKSClusterAdminPolicy so this principal is a full cluster admin
    policy_associations = {
      admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
    # NO kubernetes_groups here; not needed with cluster access policy
  }
}



}


output "cluster_name"     { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "oidc_provider_arn" { value = module.eks.oidc_provider_arn }

