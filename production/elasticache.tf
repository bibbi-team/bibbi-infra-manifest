resource "aws_elasticache_cluster" "bibbi-elc" {
  cluster_id           = "bibbi-redis"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  port                 = 6379
  parameter_group_name = "default.redis7"
}

resource "aws_elasticache_subnet_group" "elc-subnet" {
  name       = "bibbi-elc-subnet"
  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "Elc subnet group"
  }
}

resource "aws_security_group" "elc-sg" {
  name        = "elasticache-sg"
  description = "Security group for elc"
  vpc_id      = aws_vpc.bibbi-vpc.id

  tags = {
    Name = "Elc SG"
  }
}

resource "aws_security_group_rule" "ingress_redis" {
  security_group_id = aws_security_group.elc-sg.id
  type              = "ingress"
  from_port         = 6379
  to_port           = 6379
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow incoming traffic on TCP 6379"
}

# 인바운드 수정 필요
resource "aws_security_group_rule" "ingress_ssh" {
  security_group_id = aws_security_group.elc-sg.id
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "TCP"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow incoming SSH traffic"
}

resource "aws_security_group_rule" "egress_all" {
  security_group_id = aws_security_group.elc-sg.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow all outbound traffic"
}
