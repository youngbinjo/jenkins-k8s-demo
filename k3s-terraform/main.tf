terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------
# [추가] 비밀번호 및 주요 변수 선언
# 이 변수들의 실제 값은 terraform.tfvars 파일에 넣으시면 됩니다.
# ---------------------------------------------------------
variable "jenkins_admin_password" {
  type      = string
  sensitive = true
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

data "aws_availability_zones" "available" {}

# 최신 Ubuntu 22.04 AMI 찾기
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  az                 = data.aws_availability_zones.available.names[0]
  domain_name        = "ybtest.pics"
}

# 1) VPC
resource "aws_vpc" "this" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 2) Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidr
  availability_zone       = local.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# 3) Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 4) Route Table (Public)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 5) Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-sg"
  description = "SG for k3s node"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Application Port"
    from_port = 8080 
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# 6) IAM 인스턴스 프로파일 설정
resource "aws_iam_instance_profile" "k3s_profile" {
  name = "${var.project_name}-k3s-profile"
  role = "EC2-Route53-AutoUpdate-Role"
}

# 7) EC2 Spot Instance Request
resource "aws_spot_instance_request" "k3s_node" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.k3s_profile.name

  spot_price           = "0.11"
  spot_type            = "one-time"
  wait_for_fulfillment = true

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  # [수정] user_data에 비밀번호 변수와 Zone ID를 추가로 전달합니다.
  user_data = templatefile("${path.module}/user_data.sh", {
    GITHUB_TOKEN = var.github_token
    JENKINS_PW   = var.jenkins_admin_password
    GRAFANA_PW   = var.grafana_admin_password
    ZONE_ID      = aws_route53_zone.selected.zone_id
  })

  tags = {
    Name = "${var.project_name}-k3s-node-spot"
  }

  provisioner "local-exec" {
    command = "aws ec2 create-tags --resources ${self.spot_instance_id} --tags Key=Name,Value=${var.project_name}-k3s-node --region ${var.region}"
  }
}

# 8) Route 53 호스팅 영역
resource "aws_route53_zone" "selected" {
  name = local.domain_name
}
# 9) Route 53 A 레코드 자동 업데이트 설정
resource "aws_route53_record" "jenkins" {
  zone_id = aws_route53_zone.selected.zone_id
  name    = "jenkins.${local.domain_name}"
  type    = "A"
  ttl     = "60"

  # Spot 인스턴스의 퍼블릭 IP를 자동으로 가져옵니다.
  records = [aws_spot_instance_request.k3s_node.public_ip]
}

resource "aws_route53_record" "grafana" {
  zone_id = aws_route53_zone.selected.zone_id
  name    = "grafana.${local.domain_name}"
  type    = "A"
  ttl     = "60"

  records = [aws_spot_instance_request.k3s_node.public_ip]
}

# 필요 시 와일드카드 레코드도 자동으로 관리할 수 있습니다.
resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.selected.zone_id
  name    = "*.${local.domain_name}"
  type    = "A"
  ttl     = "60"

  records = [aws_spot_instance_request.k3s_node.public_ip]
}