resource "aws_iam_role" "apprunner" {
  name = "t3-apprunner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "t3-apprunner-role"
    Project = "t3"
  }
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr" {
  role       = aws_iam_role.apprunner.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

resource "aws_security_group" "apprunner_vpc_connector" {
  name        = "t3-apprunner-vpc-connector-sg"
  description = "Security group for AppRunner VPC connector"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name    = "t3-apprunner-sg"
    Project = "t3"
  }
}

resource "aws_apprunner_vpc_connector" "this" {
  vpc_connector_name = "t3-${var.service_name}-vpc-connector"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.apprunner_vpc_connector.id]

  tags = {
    Name    = "t3-${var.service_name}-vpc-connector"
    Project = "t3"
  }
}

resource "aws_apprunner_service" "this" {
  service_name = var.service_name

  source_configuration {
    image_repository {
      image_configuration {
        port = "8000"
        runtime_environment_variables = var.env_vars
      }
      image_identifier      = var.image_uri
      image_repository_type = "ECR"
    }
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner.arn
    }
    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu    = var.cpu
    memory = var.memory
  }

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.this.arn
    }
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/api/v1/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  tags = {
    Name    = var.service_name
    Project = "t3"
  }
}
