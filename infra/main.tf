# One small EC2 instance running k3s, Argo CD and Kyverno. No SSH: access is through SSM Session Manager.
# Why not EKS: the EKS control plane alone is about $73/month. The Kubernetes skills are the same.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.70" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "k8s-gitops-platform", ManagedBy = "terraform", Owner = var.owner }
  }
}

data "aws_availability_zones" "az" {
  #checkov:skip=CKV_AWS_394:Only the first zone is used
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "this" {
  cidr_block           = "10.40.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "k3s-vpc" }
  #checkov:skip=CKV2_AWS_11:Flow logs omitted to keep the one-day lab cheap; see aws-secure-landing-zone
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
}

# Public subnet for outbound only (pull images, reach SSM). The security group allows no inbound traffic.
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.40.0.0/24"
  availability_zone = data.aws_availability_zones.az.names[0]
  tags              = { Name = "k3s-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "node" {
  name        = "k3s-node"
  description = "No inbound. Outbound HTTPS and DNS only."
  vpc_id      = aws_vpc.this.id
  egress {
    description = "HTTPS for images, SSM and GitHub"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "HTTP for OS package mirrors"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #checkov:skip=CKV_AWS_382:Egress limited to 80/443; destinations vary (registries, GitHub, SSM)
}

resource "aws_iam_role" "node" {
  name = "k3s-node"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "node" {
  name = "k3s-node"
  role = aws_iam_role.node.name
}

resource "aws_instance" "k3s" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.node.id]
  iam_instance_profile        = aws_iam_instance_profile.node.name
  associate_public_ip_address = true
  monitoring                  = true
  ebs_optimized               = true
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/bootstrap.sh.tftpl", {
    repo_url       = "https://github.com/${var.github_repo}.git"
    k3s_version    = var.k3s_version
    argocd_version = var.argocd_version
    kyverno_chart  = var.kyverno_version
  })

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "k3s-gitops" }
  #checkov:skip=CKV_AWS_88:Public IP is for outbound only; the security group has no inbound rules and access is via SSM
  #checkov:skip=CKV2_AWS_41:Instance profile is attached (aws_iam_instance_profile.node)
}
