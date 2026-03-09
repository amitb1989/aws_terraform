# Get cluster connection details from the EKS module you already applied
data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Kubernetes provider that talks to your EKS cluster
provider "kubernetes" {
  alias                  = "eks"
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Helm provider backed by the same cluster
provider "helm" {
  alias = "eks"

  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
    # NOTE: no 'exec {}' block here. 'exec' is only valid in this nested kubernetes block,
    # but since we already have a token, we don't need exec.
  }
}

# -------------------------------
# IRSA for AWS Load Balancer Controller
# -------------------------------
module "irsa_alb" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                              = "${module.eks.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

# ServiceAccount annotated with IRSA role for ALB Controller
resource "kubernetes_service_account" "alb_sa" {
  provider = kubernetes.eks

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.irsa_alb.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }
}

# AWS Load Balancer Controller via Helm
resource "helm_release" "alb_ingress" {
  provider = helm.eks

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  values = [jsonencode({
    clusterName = module.eks.cluster_name
    region      = var.region
    vpcId       = module.network.vpc_id
    serviceAccount = {
      create = false
      name   = kubernetes_service_account.alb_sa.metadata[0].name
    }
  })]

  depends_on = [
    module.eks,
    kubernetes_service_account.alb_sa
  ]
}

# IMPORTANT:
# REMOVE the EBS CSI resources from root to avoid conflicts:
# - module "irsa_ebs"
# - resource "aws_eks_addon" "ebs_csi"
# Manage EBS CSI ONLY in the EKS module via cluster_addons (Phase-2).