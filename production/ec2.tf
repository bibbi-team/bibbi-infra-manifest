resource "aws_instance" "vpn_bastion" {
  ami           = "ami-04599ab1182cd7961"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.public[0].id
  associate_public_ip_address = true
  security_groups = [aws_security_group.allow_ssh.id, aws_security_group.allow_ovpn.id]

  lifecycle {
    ignore_changes = [security_groups]
  }

  tags = {
    Name = "bastion-host"
  }
}

resource "aws_eip" "bastion_ip" {
  instance = aws_instance.vpn_bastion.id
  domain   = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "bastion-eip"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.bibbi-vpc.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "allow_ovpn" {
  name        = "allow_ovpn_dashboard_sg"
  description = "Allow OVPN Dashboard inbound traffic"
  vpc_id      = aws_vpc.bibbi-vpc.id

  tags = {
    Name = "allow_ovpn_dashboard"
  }
}


resource "aws_security_group_rule" "allow_ovpn_dash" {
  type = "ingress"
  description      = "ovpn Dashboard from VPC"
  from_port        = 1194
  to_port          = 1194
  protocol         = "tcp"
  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
  security_group_id = aws_security_group.allow_ovpn.id
}


resource "aws_security_group_rule" "allow_ovpn_eg" {
  type = "egress"
  description      = "egress for ovpn"
  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
  security_group_id = aws_security_group.allow_ovpn.id
}
