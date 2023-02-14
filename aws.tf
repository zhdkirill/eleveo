locals {
  image       = "ami-0d1ddd83282187d18" # Ubuntu Server 22.04
  flavor      = "t2.micro"
  volume_size = 8
  volume_type = "gp3"
  user        = "ubuntu"
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "eleveo" {
  cidr_block = "10.0.0.0/20"

  tags = {
    Name = "eleveo-vpc"
  }
}

resource "aws_subnet" "eleveo" {
  vpc_id     = aws_vpc.eleveo.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "eleveo-subnet"
  }
}

resource "aws_internet_gateway" "eleveo" {
  vpc_id = aws_vpc.eleveo.id

  tags = {
    Name = "eleveo-internet-gateway"
  }
}

resource "aws_route_table" "internet" {
  vpc_id = aws_vpc.eleveo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eleveo.id
  }

  tags = {
    "Name" = "internet-route-table"
  }
}

resource "aws_route_table_association" "internet" {
  subnet_id      = aws_subnet.eleveo.id
  route_table_id = aws_route_table.internet.id
}


resource "aws_security_group" "eleveo" {
  name        = "eleveo-security-group"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.eleveo.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eleveo-security-group"
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "eleveo" {
  key_name   = "eleveo-key-pair"
  public_key = tls_private_key.ssh.public_key_openssh
}

data "local_file" "cloud-init" {
  filename = "./cloud-init.yaml"
}

data "cloudinit_config" "ansible" {
  gzip          = false
  base64_encode = false
  part {
    content_type = "text/cloud-config"
    content      = data.local_file.cloud-init.content
  }
}

resource "aws_instance" "eleveo" {
  ami                         = local.image
  instance_type               = local.flavor
  vpc_security_group_ids      = [aws_security_group.eleveo.id]
  subnet_id                   = aws_subnet.eleveo.id
  key_name                    = aws_key_pair.eleveo.key_name
  user_data                   = data.cloudinit_config.ansible.rendered
  associate_public_ip_address = true

  root_block_device {
    volume_size           = local.volume_size
    volume_type           = local.volume_type
    delete_on_termination = true
  }

  tags = {
    Name = "eleveo-instance"
  }
}

resource "local_sensitive_file" "ssh_private_key" {
  filename        = "${path.module}/.ssh/id_generated"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = 0600
}

output "instance_ip" {
  value = aws_instance.eleveo.public_ip
}