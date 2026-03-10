# Get cluster connection details from the EKS module you already applied
data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# # Kubernetes provider that talks to your EKS cluster

provider "kubernetes" {
  alias = "eks"

  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", var.region,
      "--role-arn", var.admin_role_arn
    ]
  }
}
provider "helm" {
  alias = "eks"

  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.region,
        "--role-arn", var.admin_role_arn
      ]
    }
  }
}
# -------------------------------
# IRSA for AWS Load Balancer Controller
# -------------------------------
module "irsa_ebs" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name             = "${module.eks.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    eks = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}
# IRSA for AWS Load Balancer Controller
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


resource "time_sleep" "wait_for_access" {
  create_duration = "45s"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "aws-ebs-csi-driver"
  addon_version = "v1.56.0-eksbuild.1"

  # IMPORTANT: wire IRSA role to the controller service account
  service_account_role_arn = module.irsa_ebs.iam_role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    module.eks,
    module.irsa_ebs
  ]
}