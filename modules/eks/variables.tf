variable "cluster_name"    { 
                                type = string
                                default = "eks-cluster-assement" 
                              }                 
variable "vpc_id"             { type = string }
variable "name"             { type = string }
variable "region"    { 
                                type = string
                                default = "ap-south-1" 
                              }
variable "private_subnet_ids" { 
                                type = list(string)
                              }
variable "public_subnet_ids" { 
                                type = list(string)
                              }
variable "cluster_version"    { 
                                type = string
                                default = "1.29" 
                              }
variable "node_instance_types"{ 
                                type = list(string)
                                default = ["t3.large"] 
                              }
variable "desired_size"       { 
                                type = number
                                default = 3 
                              }
variable "min_size"           { 
                                type = number
                                default = 2 
                              }
variable "max_size"           { 
                                type = number
                                default = 6 
                              }
variable "tags"               { 
                                type = map(string)
                                default = {} 
                            }
# variable "ebs_csi_irsa_role_arn" {
#   type        = string
#   description = "IRSA role ARN to use for the aws-ebs-csi-driver add-on service account"
#   default     = null
# }

variable "admin_role_arn" {
  type        = string
  description = "IAM role ARN that should get cluster-admin (system:masters) access"
}