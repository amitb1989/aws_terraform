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

  eks_managed_node_groups = {
    default = {
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
      instance_types = var.node_instance_types
      subnets        = var.private_subnet_ids
      tags           = var.tags
    }
  }

  # cluster_addons = {
  #   coredns = { most_recent = true }
  #   kube-proxy = { most_recent = true }
  #   vpc-cni = { most_recent = true }
  #   aws-ebs-csi-driver = {
  #     most_recent = true
  #     # IRSA for EBS CSI driver
  #     service_account_role_arn = var.ebs_csi_irsa_role_arn
  #   }
  # }

  
  # 👇 All add-ons must be inside this map
  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }

    # ⭐ Enable EBS CSI here (Phase-2)
    aws-ebs-csi-driver = {
      most_recent = true
      # Do not set service_account_role_arn unless you have a custom need
    }
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


# # IRSA: EBS CSI driver
# module "irsa_ebs" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "~> 5.39"

#   role_name = "${local.cluster_name}-ebs-csi"
#   attach_ebs_csi_policy = true

#   oidc_providers = {
#     eks = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
#     }
#   }
# }

# # ALB Ingress Controller (AWS Load Balancer Controller) via Helm
# resource "helm_release" "alb_ingress" {
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"
#   version    = "1.8.1"

#   create_namespace = false

#   values = [jsonencode({
#     clusterName = module.eks.cluster_name
#     serviceAccount = {
#       create = false
#       name   = "aws-load-balancer-controller"
#     }
#     region = var.region
#     vpcId  = var.vpc_id
#   })]

#   depends_on = [module.eks]
# }

# # IRSA for ALB Controller
# module "irsa_alb" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "~> 5.39"

#   role_name                         = "${local.cluster_name}-alb-controller"
#   attach_load_balancer_controller_policy = true
#   oidc_providers = {
#     eks = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
#     }
#   }
# }

# resource "kubernetes_service_account" "alb_sa" {
#   metadata {
#     name      = "aws-load-balancer-controller"
#     namespace = "kube-system"
#     annotations = {
#       "eks.amazonaws.com/role-arn" = module.irsa_alb.iam_role_arn
#     }
#   }
# }