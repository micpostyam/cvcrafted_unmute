# Variables Terraform pour la configuration du déploiement Unmute
# Ce fichier définit toutes les variables personnalisables

# ============================================
# CONFIGURATION AWS DE BASE
# ============================================

variable "aws_region" {
  description = "Région AWS où déployer l'infrastructure"
  type        = string
  default     = "eu-west-1" # Irlande - proche de la France et moins cher
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
  default     = "g4dn.xlarge" # NVIDIA T4 16GB, 4 vCPUs, 16GB RAM
  
  validation {
    condition = contains([
      "g4dn.xlarge",   # T4 16GB - Recommandé pour budget
      "g4dn.2xlarge",  # T4 16GB + plus de CPU/RAM
      "g5.xlarge",     # A10G 24GB - Plus puissant
      "g5.2xlarge"     # A10G 24GB + plus de CPU/RAM
    ], var.instance_type)
    error_message = "Type d'instance non supporté. Utilisez g4dn.xlarge, g4dn.2xlarge, g5.xlarge ou g5.2xlarge."
  }
}

variable "max_spot_price" {
  description = "Prix maximum pour l'instance Spot (en USD/heure)"
  type        = string
  default     = "0.20" # ~30€/mois max pour g4dn.xlarge
}

variable "disk_size_gb" {
  description = "Taille du disque système en GB"
  type        = number
  default     = 50 # Suffisant pour Docker images + logs
  
  validation {
    condition     = var.disk_size_gb >= 30 && var.disk_size_gb <= 200
    error_message = "La taille du disque doit être entre 30GB et 200GB."
  }
}

# ============================================
# CONFIGURATION SSH ET SÉCURITÉ
# ============================================

variable "ssh_public_key" {
  description = "Clé publique SSH pour l'accès à l'instance (contenu du fichier ~/.ssh/id_rsa.pub)"
  type        = string
  
  validation {
    condition     = length(var.ssh_public_key) > 100
    error_message = "La clé SSH publique semble invalide (trop courte)."
  }
}

variable "allowed_ssh_cidr" {
  description = "Adresses IP autorisées pour SSH (CIDR). Utilisez votre IP publique pour plus de sécurité"
  type        = list(string)
  default     = ["0.0.0.0/0"] # ATTENTION: Autorise tout le monde - à restreindre en production
}

# ============================================
# CONFIGURATION APPLICATION
# ============================================

variable "github_repo" {
  description = "Repository GitHub à cloner (format: username/repo-name)"
  type        = string
  default     = "votre-username/unmute" # À remplacer par votre fork
}

variable "mistral_api_key" {
  description = "Clé API Mistral AI pour le LLM"
  type        = string
  sensitive   = true # Terraform ne montrera pas cette valeur dans les logs
  
  validation {
    condition     = length(var.mistral_api_key) > 10
    error_message = "La clé API Mistral semble invalide."
  }
}

variable "hugging_face_token" {
  description = "Token Hugging Face pour télécharger les modèles Moshi"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.hugging_face_token) > 10
    error_message = "Le token Hugging Face semble invalide."
  }
}

# ============================================
# CONFIGURATION OPTIONNELLE
# ============================================

variable "enable_auto_shutdown" {
  description = "Activer l'arrêt automatique nocturne pour économiser"
  type        = bool
  default     = true
}

variable "shutdown_time" {
  description = "Heure d'arrêt automatique (format HH:MM)"
  type        = string
  default     = "23:00"
  
  validation {
    condition     = can(regex("^[0-2][0-9]:[0-5][0-9]$", var.shutdown_time))
    error_message = "Format d'heure invalide. Utilisez HH:MM (ex: 23:00)."
  }
}

variable "startup_time" {
  description = "Heure de démarrage automatique (format HH:MM)"
  type        = string
  default     = "08:00"
  
  validation {
    condition     = can(regex("^[0-2][0-9]:[0-5][0-9]$", var.startup_time))
    error_message = "Format d'heure invalide. Utilisez HH:MM (ex: 08:00)."
  }
}

# ============================================
# TAGS ET MÉTADONNÉES
# ============================================

variable "additional_tags" {
  description = "Tags supplémentaires à appliquer aux ressources"
  type        = map(string)
  default = {
    Owner       = "admin"
    CostCenter  = "development"
    AutoShutdown = "enabled"
  }
}
