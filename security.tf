# KMS CMK for S3/logs/secrets
# resource "aws_kms_key" "logs" {
#   description             = "KMS for central logs"
#   enable_key_rotation     = true
#   deletion_window_in_days = 7
#   tags = local.tags
# }

resource "aws_s3_bucket" "central_logs" {
  bucket        = "${var.env}-central-logs-${data.aws_caller_identity.this.account_id}"
  force_destroy = false
  tags          = local.tags
}

data "aws_caller_identity" "this" {}

resource "aws_s3_bucket_versioning" "central_logs_v" {
  bucket = aws_s3_bucket.central_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "central_logs_sse" {
  bucket = aws_s3_bucket.central_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.logs.arn
    }
  }
}

resource "aws_s3_bucket_logging" "central_logs_access" {
  bucket        = aws_s3_bucket.central_logs.id
  target_bucket = aws_s3_bucket.central_logs.id
  target_prefix = "access-logs/"
}

# CloudTrail -> central logs bucket
resource "aws_cloudtrail" "org" {
  name                          = "${var.env}-trail"
  s3_bucket_name                = aws_s3_bucket.central_logs.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.logs.arn
  event_selector {
    read_write_type           = "All"
    include_management_events = true
    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]  # log data events if needed
    }
  }
  tags = local.tags
}

# GuardDuty
resource "aws_guardduty_detector" "this" {
  enable = true
  datasources {
    s3_logs { enable = true }
    kubernetes {
      audit_logs { enable = true }
    }
  }
  tags = local.tags
}

# Security Hub
resource "aws_securityhub_account" "this" {}
resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.this]
}

# Example IAM least privilege: restricted role for app S3 access via IRSA (pattern)
# module "irsa_app" ... attach a custom policy with minimal S3 prefixes only if needed

resource "aws_s3_bucket_policy" "central_logs_policy" {
  bucket = aws_s3_bucket.central_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.central_logs.arn
      },
      {
        Sid = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.central_logs.arn}/AWSLogs/${data.aws_caller_identity.this.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_kms_key" "logs" {
  description             = "KMS for central logs"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_key_policy" "logs_policy" {
  key_id = aws_kms_key.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Encrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.this.account_id}:trail/${var.env}-trail"
          }
        }
      },
      {
        Sid = "Allow CloudTrail to decrypt (S3 validation)"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}