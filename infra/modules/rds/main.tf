terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_password" "master" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnets"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.identifier}-sg"
  description = "Database access for ${var.identifier}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.identifier}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = toset(var.allowed_cidr_blocks)

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  from_port         = var.port
  to_port           = var.port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_db_instance" "this" {
  identifier                   = var.identifier
  engine                       = "postgres"
  engine_version               = var.engine_version
  instance_class               = var.instance_class
  allocated_storage            = var.allocated_storage
  max_allocated_storage        = var.max_allocated_storage
  db_name                      = var.db_name
  username                     = var.username
  password                     = random_password.master.result
  port                         = var.port
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.this.id]
  multi_az                     = var.multi_az
  backup_retention_period      = var.backup_retention_period
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${var.identifier}-final"
  publicly_accessible          = false
  storage_encrypted            = true
  auto_minor_version_upgrade   = true
  apply_immediately            = true
  performance_insights_enabled = true

  tags = merge(var.tags, {
    Name = var.identifier
  })
}

resource "aws_secretsmanager_secret" "connection" {
  name = "${var.identifier}-connection"

  tags = merge(var.tags, {
    Name = "${var.identifier}-connection"
  })
}

resource "aws_secretsmanager_secret_version" "connection" {
  secret_id = aws_secretsmanager_secret.connection.id
  secret_string = jsonencode({
    username = var.username
    password = random_password.master.result
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = var.port
    dbname   = var.db_name
    url      = "postgresql+psycopg://${var.username}:${random_password.master.result}@${aws_db_instance.this.address}:${var.port}/${var.db_name}"
  })
}
