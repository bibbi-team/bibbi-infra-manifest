resource "aws_ecs_cluster" "bibbi-cluster-prod" {
  name = "bibbi-cluster-prod"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_secretsmanager_secret" "bibbi-ecs-secret" {
  name = "bibbi-ecs-secret-production"
}

resource "aws_secretsmanager_secret_version" "bibbi-ecs-secret-version" {
  secret_id     = aws_secretsmanager_secret.bibbi-ecs-secret.id
  secret_string = jsonencode(local.container_secrets)
}


resource "aws_ecs_task_definition" "bibbi-backend" {
  family = "bibbi-backend-prod"
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  depends_on = [aws_secretsmanager_secret_version.bibbi-ecs-secret-version]
  lifecycle {
    ignore_changes = [
      container_definitions
    ]
  }
  container_definitions = jsonencode([
    {
      name      = "api"
      image     = local.ecs_image_url
      cpu       = 2048
      memory    = 4096
      essential = true
      portMappings = [
        {
          containerPort = local.container_port
          hostPort      = local.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/bibbi-backend-prod"
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs",
          "awslogs-create-group"= "true"
        }
      }
      dockerLabels = {
        "PROMETHEUS_EXPORTER_PATH" =  "/actuator/prometheus",
        "PROMETHEUS_EXPORTER_PORT" = "8080"
      }
      secrets = [
        for key, value in local.container_secrets :  {
          name      = key
          valueFrom = "${aws_secretsmanager_secret_version.bibbi-ecs-secret-version.arn}:${key}::"
        }
      ]
    }
  ])
}

data "aws_iam_policy_document" "ecs_task_execution_role" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "bibbi-prod-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "ecs_secret_manager_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy     = data.aws_iam_policy_document.secret_manager_policy.json
}

data "aws_iam_policy_document" "secret_manager_policy" {
  statement {
    effect = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.bibbi-ecs-secret.arn,
      aws_secretsmanager_secret.bibbi-ecs-secret-dev.arn]
  }
}

resource "aws_iam_role_policy" "ecs_log_group_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy     = data.aws_iam_policy_document.log_group_policy.json
}

data "aws_iam_policy_document" "log_group_policy" {
  statement {
    effect = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"]
  }
}


resource "aws_ecs_service" "bibbi-backend" {
  name            = "bibbi-backend"
  cluster         = aws_ecs_cluster.bibbi-cluster-prod.id
  task_definition = aws_ecs_task_definition.bibbi-backend.arn
  desired_count   = 2

  launch_type     = "FARGATE"
  health_check_grace_period_seconds = 30
  #depends_on      = [aws_iam_role_policy.foo]

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }

  deployment_circuit_breaker {
    enable = true
    rollback = true
  }
  depends_on = [aws_lb_listener.http_to_https, aws_lb_listener.https_forward, aws_iam_role_policy_attachment.ecs_task_execution_role]
  network_configuration {
    security_groups  = [aws_security_group.bibbi-prod-ecs-sg.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.bibbi-prod.arn
    container_name   = "api"
    container_port   = local.container_port
  }
}


data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs-role" {
  name               = "bibbi-backend-ecs-role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json # (not shown)

  inline_policy {
    name   = "bibbi-backend-ecs-policy"
    policy = data.aws_iam_policy_document.inline_policy.json
  }
}

resource "aws_iam_role_policy_attachment" "sto-readonly-role-policy-attach" {
  role       = aws_iam_role.ecs-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "inline_policy" {
  statement {
    actions   = ["ec2:DescribeAccountAttributes"]
    resources = ["*"]
  }
}

resource "aws_security_group" "bibbi-prod-ecs-sg" {
  name        = "bibbi-prod-ecs-sg"
  description = "Prod ECS Security Group"
  vpc_id      = aws_vpc.bibbi-vpc.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    security_groups = [aws_security_group.bibbi-prod-alb-sg.id]
    from_port       = local.container_port
    to_port         = local.container_port
    protocol        = "tcp"
  }

  ingress {
    protocol  = "tcp"
    from_port       = local.container_port
    to_port         = local.container_port
    cidr_blocks      = ["10.0.0.0/16"]
  }

  tags = {
    Name = "bibbi-prod-ecs-sg"
  }
}
