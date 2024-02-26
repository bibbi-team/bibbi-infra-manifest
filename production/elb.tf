resource "aws_lb" "bibbi-prod" {
  name               = "bibbi-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.bibbi-prod-alb-sg.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

resource "aws_security_group" "bibbi-prod-alb-sg" {
  name        = "bibbi-prod-alb-sg"
  description = "Prod ALB Security Group"
  vpc_id      = aws_vpc.bibbi-vpc.id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bibbi-prod-alb-sg"
  }
}

resource "aws_lb_target_group" "bibbi-prod" {
  name     = "bibbi-prod-alb-tg"
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

resource "aws_lb_listener" "https_forward" {
  load_balancer_arn = aws_lb.bibbi-prod.arn
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn = local.alb_certificate_arn
  port              = 443
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bibbi-prod.arn
  }
}

resource "aws_lb_listener" "http_to_https" {
  load_balancer_arn = aws_lb.bibbi-prod.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
