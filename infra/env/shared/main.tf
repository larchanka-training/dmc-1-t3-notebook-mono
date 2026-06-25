locals {
  environment = "shared"
  tags = {
    Project     = "dmc-1-t3-notebook"
    Repository  = var.repository
    ManagedBy   = "terraform"
    Owner       = "t3"
    Environment = local.environment
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix        = "t3-notebook"
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  nat_gateway_mode   = var.nat_gateway_mode
  tags               = local.tags
}

module "ecr" {
  source = "../../modules/ecr"

  repositories = toset(["t3-notebook-ui", "t3-notebook-api"])
  tags         = local.tags
}

# ECR cross-region replication is an account-level singleton — managing it here
# (not inside the ecr module) prevents sibling env applies from overwriting it.
# See runbook §3.2.
resource "aws_ecr_replication_configuration" "dr" {
  count = var.dr_region != "" ? 1 : 0

  replication_configuration {
    rule {
      destination {
        region      = var.dr_region
        registry_id = data.aws_caller_identity.current.account_id
      }

      repository_filter {
        filter      = "t3-notebook"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

module "iam" {
  source = "../../modules/iam"

  name_prefix = "t3-notebook"
  tags        = local.tags
}

module "observability" {
  source = "../../modules/observability"

  cluster_name = "t3-notebook-cluster"
  tags         = local.tags
}

module "preview_alb" {
  source = "../../modules/alb"

  name       = "t3-notebook-preview-alb"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.public_subnet_ids
  tags       = local.tags
}

resource "aws_route53_zone" "t3_jsnb_org" {
  name = "t3.jsnb.org"

  tags = merge(local.tags, {
    Name = "t3.jsnb.org"
  })
}

resource "aws_service_discovery_private_dns_namespace" "preview" {
  name = var.cloud_map_namespace_name
  vpc  = module.network.vpc_id

  tags = merge(local.tags, {
    Name = var.cloud_map_namespace_name
  })
}

# ---------- Email DNS Records ----------

resource "aws_route53_record" "resend_dkim" {
  zone_id = aws_route53_zone.t3_jsnb_org.zone_id
  name    = "resend._domainkey.t3.jsnb.org"
  type    = "TXT"
  ttl     = 300
  records = ["p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDHoq5c9e1p+fTi7uhawg0Uq76gedmztt4TMuZ0714nAD90231Z0t/gwTqptJnIyc0owZx2uVCnaLxGa78sFRCaSeGPJ+uo+WmrEhHVUIw7KQxhZwpcBBbF7KQJX9p932w7Yq94J0VPGfuSWLbyzGgs4EpKOQPn9Nk5k3XLvQDtYQIDAQAB"]
}

resource "aws_route53_record" "ses_feedback_mx" {
  zone_id = aws_route53_zone.t3_jsnb_org.zone_id
  name    = "send.t3.jsnb.org"
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.us-east-1.amazonses.com"]
}

resource "aws_route53_record" "ses_spf" {
  zone_id = aws_route53_zone.t3_jsnb_org.zone_id
  name    = "send.t3.jsnb.org"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_route53_record" "dmarc" {
  zone_id = aws_route53_zone.t3_jsnb_org.zone_id
  name    = "_dmarc.t3.jsnb.org"
  type    = "TXT"
  ttl     = 300
  records = ["v=DMARC1; p=none;"]
}

resource "aws_route53_record" "ses_inbound_mx" {
  zone_id = aws_route53_zone.t3_jsnb_org.zone_id
  name    = "t3.jsnb.org"
  type    = "MX"
  ttl     = 300
  records = ["10 inbound-smtp.us-east-1.amazonaws.com"]
}

resource "aws_route53_record" "ses_domain_verification" {
  zone_id = aws_route53_zone.t3_jsnb_org.zone_id
  name    = "_amazonses.t3.jsnb.org"
  type    = "TXT"
  ttl     = 300
  records = ["3qmSw9KyJKTeT/vVg50WHgdXIXR8C1jh5dw6HMqMMtE="]
}

# ---------- Operator / on-call DR role ----------
# Read-only role granting the IAM actions the DR runbook requires (ECR
# replication, Route 53 health checks, service quotas). See runbook §5.5.
#
# Trust is scoped to explicit on-call/SSO principal ARNs (operator_principal_arns)
# — never the account root, which would let any IAM principal in the account
# (developers, CI runners, ECS task roles) assume it. When no principals are
# supplied the role is not created.
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "operator_assume" {
  count = length(var.operator_principal_arns) > 0 ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = var.operator_principal_arns
    }
  }
}

resource "aws_iam_role" "operator" {
  count              = length(var.operator_principal_arns) > 0 ? 1 : 0
  name               = "t3-notebook-operator"
  assume_role_policy = data.aws_iam_policy_document.operator_assume[0].json

  tags = merge(local.tags, {
    Name = "t3-notebook-operator"
  })
}

resource "aws_iam_role_policy" "operator_dr_readonly" {
  count = length(var.operator_principal_arns) > 0 ? 1 : 0
  name  = "dr-runbook-readonly"
  role  = aws_iam_role.operator[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DRRunbookReadOnly"
        Effect = "Allow"
        Action = [
          "ecr:DescribeRegistry",
          "route53:ListHealthChecks",
          "route53:GetHealthCheck",
          "servicequotas:ListServiceQuotas",
          "servicequotas:GetServiceQuota",
        ]
        Resource = "*"
      }
    ]
  })
}
