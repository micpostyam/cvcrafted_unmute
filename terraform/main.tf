# Configuration principale Terraform pour provisioning infrastructure AWS
# Ce fichier définit uniquement l'infrastructure de base

# Configuration du provider AWS
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configuration de la région AWS
provider "aws" {
  region = var.aws_region
  
  # Tags par défaut appliqués à toutes les ressources
  default_tags {
    tags = {
      Project     = "unmute"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Recherche de l'AMI Deep Learning optimisée pour GPU
data "aws_ami" "nvidia_gpu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 24.04)*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Création d'une paire de clés pour l'accès SSH
resource "aws_key_pair" "unmute" {
  key_name   = "unmute-${var.environment}"
  public_key = var.ssh_public_key
}

# VPC (Virtual Private Cloud) - Notre réseau virtuel privé
resource "aws_vpc" "unmute" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "unmute-vpc-${var.environment}"
  }
}

# Sous-réseau public pour notre instance
resource "aws_subnet" "unmute_public" {
  vpc_id                  = aws_vpc.unmute.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "unmute-public-subnet-${var.environment}"
  }
}

# Gateway Internet pour l'accès externe
resource "aws_internet_gateway" "unmute" {
  vpc_id = aws_vpc.unmute.id

  tags = {
    Name = "unmute-igw-${var.environment}"
  }
}

# Table de routage pour diriger le trafic vers Internet
resource "aws_route_table" "unmute_public" {
  vpc_id = aws_vpc.unmute.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.unmute.id
  }

  tags = {
    Name = "unmute-public-rt-${var.environment}"
  }
}

# Association de la table de routage avec le sous-réseau
resource "aws_route_table_association" "unmute_public" {
  subnet_id      = aws_subnet.unmute_public.id
  route_table_id = aws_route_table.unmute_public.id
}

# Récupération des zones de disponibilité
data "aws_availability_zones" "available" {
  state = "available"
}

# Groupe de sécurité (firewall) pour notre instance
resource "aws_security_group" "unmute" {
  name_prefix = "unmute-${var.environment}-"
  vpc_id      = aws_vpc.unmute.id
  description = "Security group for Unmute application"

  # SSH pour l'administration
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Règles de sortie - autoriser tout le trafic sortant
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "unmute-sg-${var.environment}"
  }
}

# Instance EC2 avec GPU
resource "aws_instance" "unmute" {
  ami                    = data.aws_ami.nvidia_gpu.id
  instance_type          = var.instance_type
  key_name              = aws_key_pair.unmute.key_name
  vpc_security_group_ids = [aws_security_group.unmute.id]
  subnet_id             = aws_subnet.unmute_public.id

  # Stockage
  root_block_device {
    volume_type           = "gp3"
    volume_size          = var.disk_size_gb
    delete_on_termination = true
    encrypted            = true
  }

  tags = {
    Name = "unmute-gpu-${var.environment}"
  }
}

# IP Elastique pour avoir une adresse fixe
resource "aws_eip" "unmute" {
  instance = aws_instance.unmute.id
  domain   = "vpc"

  depends_on = [aws_instance.unmute]

  tags = {
    Name = "unmute-eip-${var.environment}"
  }
}
