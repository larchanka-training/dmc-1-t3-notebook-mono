data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.name_prefix}-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-task-execution"
  })
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ui_task" {
  name               = "${var.name_prefix}-ui-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ui-task"
  })
}

resource "aws_iam_role" "api_task" {
  name               = "${var.name_prefix}-api-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-api-task"
  })
}

resource "aws_iam_role" "proxy_task" {
  name               = "${var.name_prefix}-proxy-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-proxy-task"
  })
}

# ECS Exec requires ssmmessages permissions on the task role
data "aws_iam_policy_document" "ecs_exec" {
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "api_task_ecs_exec" {
  name   = "ecs-exec"
  role   = aws_iam_role.api_task.name
  policy = data.aws_iam_policy_document.ecs_exec.json
}

resource "aws_iam_role_policy" "ui_task_ecs_exec" {
  name   = "ecs-exec"
  role   = aws_iam_role.ui_task.name
  policy = data.aws_iam_policy_document.ecs_exec.json
}

resource "aws_iam_role_policy" "proxy_task_ecs_exec" {
  name   = "ecs-exec"
  role   = aws_iam_role.proxy_task.name
  policy = data.aws_iam_policy_document.ecs_exec.json
}
