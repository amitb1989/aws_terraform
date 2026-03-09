resource "kubernetes_cluster_role_binding" "eks_admin" {
  provider = kubernetes.eks

  metadata {
    name = "eks-admin-binding"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "Group"
    name      = "eks-admin"
    api_group = "rbac.authorization.k8s.io"
  }
}