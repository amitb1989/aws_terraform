# modules/eks/outputs.tf
# (Only the new ones; do NOT copy cluster_name/endpoint/oidc here)

output "cluster_security_group_id" {
  description = "EKS Cluster Security Group ID"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "EKS Node Group Security Group ID"
  value       = module.eks.node_security_group_id
}