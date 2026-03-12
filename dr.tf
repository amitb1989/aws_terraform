# EBS snapshot lifecycle (Data Lifecycle Manager)
resource "aws_dlm_lifecycle_policy" "ebs_daily" {
  description        = "Daily EBS snapshots"
  execution_role_arn = aws_iam_role.dlm.arn
  policy_details {
    resource_types = ["VOLUME"]
    schedule {
      name = "daily"
      create_rule {
        interval = 24
        interval_unit = "HOURS"
        times = ["03:00"]
      }
      retain_rule { count = 7 }
      tags_to_add = { SnapshotCreator = "DLM" }
      copy_tags = true
    }
    target_tags = { Backup = "true" }
  }
  state = "ENABLED"
  tags  = local.tags
}

resource "aws_iam_role" "dlm" {
  name = "${var.env}-dlm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "dlm.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "dlm" {
  role       = aws_iam_role.dlm.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSDataLifecycleManagerServiceRole"
}

# RDS Multi-AZ (example: Postgres)
resource "aws_db_subnet_group" "rds" {
  name       = "${var.env}-rds-subnets"
  subnet_ids = module.network.private_subnet_ids
  tags       = local.tags
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.env}-pg"
  engine                  = "postgres"
  engine_version          = "16.13"
  instance_class          = "db.t4g.medium"
  allocated_storage       = 50
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.logs.arn

  username                = "appuser"
  password                = random_password.db.result

  db_subnet_group_name    = aws_db_subnet_group.rds.name

  # ✅ Use custom RDS SG
  vpc_security_group_ids  = [aws_security_group.rds.id]

  multi_az                = true
  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true
  tags                    = local.tags
}

resource "aws_security_group" "rds" {
  name        = "${var.env}-rds-sg"
  description = "Security group for RDS Postgres"
  vpc_id      = module.network.vpc_id

  # Allow EKS nodes to access Postgres (port 5432)
  ingress {
    description     = "Allow EKS nodes to access RDS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [data.aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

data "aws_security_group" "eks_nodes" {
  id = "sg-0bc262de991a1efd9"
}

resource "random_password" "db" {
  length  = 20
  special = true
}

# Route53 Failover between two regions (active-passive)
# Prereq: two ALB/NLB DNS names exported from primary and secondary stacks
variable "primary_alb_dns"  { 
                type = string 
                default="aws-load-balancer-controller-84d869c5b4-2sd8c"
                }
variable "secondary_alb_dns" { 
                type = string
                default="aws-load-balancer-controller-84d869c5b4-6fflp"
                } 
variable "hosted_zone_id"   { 
                type = string
                default="Z06063202WBOOZCAUS2QU"
                }
variable "app_dns_name"      { 
                type = string
                default="amitb-demo" 
                }

resource "aws_route53_record" "app_primary" {
  zone_id = var.hosted_zone_id
  name    = var.app_dns_name
  type    = "CNAME"
  set_identifier = "primary"
  failover_routing_policy { type = "PRIMARY" }
  records = [var.primary_alb_dns]
  ttl     = 60
  health_check_id = aws_route53_health_check.primary.id
}

resource "aws_route53_record" "app_secondary" {
  zone_id = var.hosted_zone_id
  name    = var.app_dns_name
  type    = "CNAME"
  set_identifier = "secondary"
  failover_routing_policy { type = "SECONDARY" }
  records = [var.secondary_alb_dns]
  ttl     = 60
  health_check_id = aws_route53_health_check.secondary.id
}

resource "aws_route53_health_check" "primary" {
  fqdn              = var.app_dns_name
  type              = "HTTPS"
  port              = 443
  resource_path     = "/healthz"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "secondary" {
  fqdn              = var.app_dns_name
  type              = "HTTPS"
  port              = 443
  resource_path     = "/healthz"
  failure_threshold = 3
  request_interval  = 30
}