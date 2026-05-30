resource "aws_security_group" "rds" {
  name        = "t3-rds-sg"
  description = "Security group for t3 RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "PostgreSQL from AppRunner VPC connector"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name    = "t3-rds-sg"
    Project = "t3"
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "t3-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name    = "t3-rds-subnet-group"
    Project = "t3"
  }
}

resource "aws_db_instance" "this" {
  identifier        = "t3-postgres"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "t3-postgres-final-snapshot"

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  tags = {
    Name    = "t3-postgres"
    Project = "t3"
  }
}
