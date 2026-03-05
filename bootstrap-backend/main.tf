terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.50" }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "eks-ha-dr"
      Owner     = "AmitBapodara"
      ManagedBy = "terraform"
      Purpose   = "tf-backend"
    }
  }
}

data "aws_caller_identity" "current" {}

# Create S3 bucket for TF state (must already be unique; you provided it)
resource "aws_s3_bucket" "state" {
  bucket        = var.bucket_name
  force_destroy = false
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# KMS CMK for state encryption
resource "aws_kms_key" "tf_state" {
  description             = "KMS for Terraform state encryption (account ${var.account_id})"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        "Sid" : "EnableRootFullAccess",
        "Effect" : "Allow",
        "Principal" : { "AWS" : "arn:aws:iam::${var.account_id}:root" },
        "Action" : "kms:*",
        "Resource" : "*"
      }
    ]
  })
}

# Enforce SSE-KMS on the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tf_state.arn
    }
    bucket_key_enabled = true
  }
}

# Enforce TLS-only access
data "aws_iam_policy_document" "state_bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    # Deny any non-SSL (non-TLS) access to state bucket
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]

    # Public principal (wildcard) for deny statements is valid here
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket_policy.json
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}