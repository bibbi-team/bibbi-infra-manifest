resource "aws_secretsmanager_secret" "bibbi-ecs-secret-dev" {
  name = "bibbi-ecs-secret-development"
}

resource "aws_secretsmanager_secret_version" "bibbi-ecs-secret-version-dev" {
  secret_id     = aws_secretsmanager_secret.bibbi-ecs-secret-dev.id
  secret_string = jsonencode(local.container_secrets_dev)
}

resource "aws_ecs_service" "bibbi-backend-dev" {
  name            = "bibbi-backend-dev"
  cluster         = aws_ecs_cluster.bibbi-cluster-prod.id
  task_definition = aws_ecs_task_definition.bibbi-backend-dev.arn
  desired_count   = 1

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
    security_groups  = [aws_security_group.bibbi-dev-ecs-sg.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.bibbi-dev.arn
    container_name   = "api"
    container_port   = local.container_port
  }
}

resource "aws_ecs_task_definition" "bibbi-backend-dev" {
  family = "bibbi-backend-dev"
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 4096
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  depends_on = [aws_secretsmanager_secret_version.bibbi-ecs-secret-version-dev]
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
          "awslogs-group"         = "/ecs/bibbi-backend-dev"
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs",
          "awslogs-create-group"= "true"
        }
      }
      secrets = [
      for key, value in local.container_secrets :  {
        name      = key
        valueFrom = "${aws_secretsmanager_secret_version.bibbi-ecs-secret-version-dev.arn}:${key}::"
      }
      ]
    }
  ])
}

resource "aws_security_group" "bibbi-dev-ecs-sg" {
  name        = "bibbi-dev-ecs-sg"
  description = "Dev ECS Security Group"
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

  tags = {
    Name = "bibbi-dev-ecs-sg"
  }
}

resource "aws_lb_target_group" "bibbi-dev" {
  name     = "bibbi-dev-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.bibbi-vpc.id
  target_type = "ip"

  health_check {
    enabled             = true
    interval            = 30
    path                = local.ecs_health_check_url
    timeout             = 10
    matcher             = "200"
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener_rule" "dev" {
  listener_arn = aws_lb_listener.https_forward.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bibbi-dev.arn
  }

  condition {
    host_header {
      values = ["dev.api.no5ing.kr"]
    }
  }
}
