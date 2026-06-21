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
