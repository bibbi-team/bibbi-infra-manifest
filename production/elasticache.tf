resource "aws_elasticache_serverless_cache" "bibbi-elc" {
  engine = "redis"
  name   = "bibbi-redis"
  cache_usage_limits {
    data_storage {
      maximum = 10
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 5000
    }
  }
  daily_snapshot_time      = "09:00"
  description              = "BiBBi Prod Elasticache"
  major_engine_version     = "7"
  snapshot_retention_limit = 1
  security_group_ids       = [aws_security_group.elc-sg.id]
  subnet_ids               = aws_subnet.private[*].id
}

resource "aws_security_group" "elc-sg" {
  name        = "elasticache-sg"
  description = "Security group for elc"
  vpc_id      = aws_vpc.bibbi-vpc.id

  tags = {
    Name = "Elc SG"
  }
}

# 인바운드 수정 필요
resource "aws_security_group_rule" "ingress_redis" {
  security_group_id = aws_security_group.elc-sg.id
  type              = "ingress"
  from_port         = 6379
  to_port           = 6381
  protocol          = "TCP"
  cidr_blocks       = [local.vpc_cidr]
  description       = "allow incoming traffic on TCP 6379"
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
