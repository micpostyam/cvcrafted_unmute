# Variables Terraform pour le provisioning d'infrastructure

# ============================================
# CONFIGURATION AWS DE BASE
# ============================================

variable "aws_region" {
  description = "Région AWS où déployer l'infrastructure"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environnement de déploiement (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être dev, staging ou prod."
  }
}

# ============================================
# CONFIGURATION INSTANCE EC2
# ============================================

variable "instance_type" {
  description = "Type d'instance EC2 avec GPU"
  type        = string
  default     = "g4dn.xlarge"
  
  validation {
    condition = contains([
      "g4dn.xlarge",
      "g4dn.2xlarge",
      "g5.xlarge",
      "g5.2xlarge"
    ], var.instance_type)
    error_message = "Type d'instance non supporté."
  }
}

variable "disk_size_gb" {
  description = "Taille du disque système en GB"
  type        = number
  default     = 100
  
  validation {
    condition     = var.disk_size_gb >= 30 && var.disk_size_gb <= 200
    error_message = "La taille du disque doit être entre 30GB et 200GB."
  }
}

# ============================================
# CONFIGURATION SSH ET SÉCURITÉ
# ============================================

variable "ssh_public_key" {
  description = "Clé publique SSH pour l'accès à l'instance"
  type        = string
  
  validation {
    condition     = length(var.ssh_public_key) > 100
    error_message = "La clé SSH publique semble invalide."
  }
}

variable "allowed_ssh_cidr" {
  description = "Adresses IP autorisées pour SSH (CIDR)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
