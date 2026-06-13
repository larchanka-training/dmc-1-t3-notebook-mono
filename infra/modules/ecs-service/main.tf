data "aws_region" "current" {}

locals {
  ingress_ports = distinct(flatten([
    for container in var.container_definitions : [
      for port_mapping in container.port_mappings : port_mapping.container_port
    ]
  ]))

  ingress_sg_rules = {
    for rule in flatten([
      for security_group_index, security_group_id in var.ingress_security_group_ids : [
        for port in local.ingress_ports : {
          id                = "${security_group_index}-${port}"
          security_group_id = security_group_id
          port              = port
        }
      ]
    ]) : rule.id => rule
  }

  ingress_cidr_rules = {
    for rule in flatten([
      for cidr in var.ingress_cidr_blocks : [
        for port in local.ingress_ports : {
          id   = "${replace(cidr, "/", "-")}-${port}"
          cidr = cidr
          port = port
        }
      ]
    ]) : rule.id => rule
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_in_days

  tags = merge(var.tags, {
    Name = "/ecs/${var.name}"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Service access for ${var.name}"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "from_security_groups" {
  for_each = local.ingress_sg_rules

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value.security_group_id
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "from_cidrs" {
  for_each = local.ingress_cidr_rules

  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value.cidr
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_service_discovery_service" "this" {
  count = var.service_discovery == null ? 0 : 1

  name = var.service_discovery.discovery_name

  dns_config {
    namespace_id = var.service_discovery.namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_lb_target_group" "this" {
  count = var.load_balancer == null ? 0 : 1

  name        = substr(replace(var.name, "_", "-"), 0, 32)
  port        = var.load_balancer.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = var.load_balancer.health_check_path
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_lb_listener_rule" "this" {
  count = var.load_balancer == null ? 0 : 1

  listener_arn = var.load_balancer.listener_arn
  priority     = var.load_balancer.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  condition {
    path_pattern {
      values = var.load_balancer.path_patterns
    }
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    for container in var.container_definitions : merge(
      {
        name      = container.name
        image     = container.image
        essential = container.essential
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.this.name
            awslogs-region        = data.aws_region.current.name
            awslogs-stream-prefix = container.name
          }
        }
      },
      length(container.port_mappings) > 0 ? {
        portMappings = [
          for port_mapping in container.port_mappings : {
            containerPort = port_mapping.container_port
            hostPort      = try(port_mapping.host_port, port_mapping.container_port)
            protocol      = try(port_mapping.protocol, "tcp")
          }
        ]
      } : {},
      length(container.environment) > 0 ? {
        environment = [
          for key, value in container.environment : {
            name  = key
            value = value
          }
        ]
      } : {},
      length(container.secrets) > 0 ? {
        secrets = [
          for key, value in container.secrets : {
            name      = key
            valueFrom = value
          }
        ]
      } : {},
      try(container.command, null) != null ? {
        command = container.command
      } : {},
      try(container.entrypoint, null) != null ? {
        entryPoint = container.entrypoint
      } : {},
      try(container.health_check, null) != null ? {
        healthCheck = {
          command     = container.health_check.command
          interval    = try(container.health_check.interval, 30)
          retries     = try(container.health_check.retries, 3)
          timeout     = try(container.health_check.timeout, 5)
          startPeriod = try(container.health_check.start_period, 0)
        }
      } : {}
    )
  ])

  tags = merge(var.tags, {
    Name = var.name
  })
}

resource "aws_ecs_service" "this" {
  name                               = var.name
  cluster                            = var.cluster_arn
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  enable_execute_command             = true

  network_configuration {
    assign_public_ip = var.assign_public_ip
    security_groups  = [aws_security_group.this.id]
    subnets          = var.subnet_ids
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer == null ? [] : [var.load_balancer]

    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.service_discovery == null ? [] : [var.service_discovery]

    content {
      registry_arn   = aws_service_discovery_service.this[0].arn
      container_name = service_registries.value.container_name
    }
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}
