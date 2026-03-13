variable "region" {
  type        = string
  description = "AWS region for deployments"
  default     = "ap-south-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS SSO profile name from ~/.aws/config"
  default     = "terraform-admin"
}

provider "aws" {
  region  = var.region
  #profile = var.aws_profile

  # Secure default tags for auditability and cost allocation
  default_tags {
    tags = {
      Project     = "eks-ha-dr"
      Owner       = "AmitBapodara"
      AccountId   = "888696596070"
      ManagedBy   = "terraform"
      Environment = terraform.workspace
    }
  }
}

# (Optional) If you use helm/kubernetes providers, declare them after EKS is created
# and point them to your EKS cluster data sources.
