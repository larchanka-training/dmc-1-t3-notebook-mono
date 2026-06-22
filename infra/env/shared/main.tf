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
