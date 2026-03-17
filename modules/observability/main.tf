# resource "aws_cloudwatch_log_group" "eks_controlplane" {
#   name              = "/aws/eks/${module.eks.cluster_name}/cluster"
#   retention_in_days = 30 # change as needed
#   #tags              = local.tags
# }
