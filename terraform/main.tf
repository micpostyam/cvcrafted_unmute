# Configuration principale Terraform pour déployer Unmute sur AWS
# Ce fichier définit l'infrastructure complète nécessaire

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

# Recherche de l'AMI Ubuntu optimisée pour GPU
data "aws_ami" "ubuntu_gpu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
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

  # Règles d'entrée (ingress)
  
  # SSH pour l'administration
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ATTENTION: Restreindre à votre IP en production
  }

  # Frontend Next.js
  ingress {
    description = "Frontend (Next.js)"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend API
  ingress {
    description = "Backend API"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Règles de sortie (egress) - autoriser tout le trafic sortant
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

# Instance EC2 avec GPU (On-Demand pour éviter les limites Spot)
resource "aws_instance" "unmute" {
  # Configuration de base
  ami                    = data.aws_ami.ubuntu_gpu.id
  instance_type          = var.instance_type
  key_name              = aws_key_pair.unmute.key_name
  vpc_security_group_ids = [aws_security_group.unmute.id]
  subnet_id             = aws_subnet.unmute_public.id

  # Stockage optimisé
  root_block_device {
    volume_type           = "gp3"
    volume_size          = var.disk_size_gb
    delete_on_termination = true
    encrypted            = true
  }

  # Script d'initialisation automatique
  user_data = base64encode(templatefile("${path.module}/scripts/setup-gpu.sh", {
    github_repo            = var.github_repo
    mistral_api_key       = var.mistral_api_key
    hugging_face_token    = var.hugging_face_token
    environment           = var.environment
    enable_auto_shutdown  = var.enable_auto_shutdown
    shutdown_time         = var.shutdown_time
    KYUTAI_LLM_URL        = "https://api.mistral.ai/v1"
    KYUTAI_LLM_API_KEY    = var.mistral_api_key
    HUGGING_FACE_HUB_TOKEN = var.hugging_face_token
  }))

  tags = {
    Name = "unmute-gpu-${var.environment}"
    Type = "on-demand-instance"
  }
}

# IP Elastique pour avoir une adresse fixe
resource "aws_eip" "unmute" {
  instance = aws_instance.unmute.id
  domain   = "vpc"

  # Attendre que l'instance soit créée
  depends_on = [aws_instance.unmute]

  tags = {
    Name = "unmute-eip-${var.environment}"
  }
}
