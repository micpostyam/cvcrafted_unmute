# Infrastructure Terraform pour Unmute

Ce dossier contient la configuration Terraform pour provisionner l'infrastructure AWS nécessaire à l'application Unmute.

## 🏗️ Infrastructure provisionnée

- **VPC** : Réseau virtuel privé
- **Subnet** : Sous-réseau public
- **Security Group** : Groupe de sécurité (ports 22, 80, 443)
- **Instance EC2** : Instance GPU (g4dn.xlarge par défaut)
- **Elastic IP** : Adresse IP publique fixe
- **Key Pair** : Paire de clés SSH

## 🚀 Utilisation

### 1. Configuration

```bash
# Copier le fichier d'exemple
cp terraform.tfvars.example terraform.tfvars

# Éditer avec vos valeurs
nano terraform.tfvars
```

### 2. Déploiement

```bash
# Initialiser Terraform
terraform init

# Planifier le déploiement
terraform plan

# Appliquer la configuration
terraform apply
```

### 3. Connexion

```bash
# Se connecter via SSH (IP affichée après terraform apply)
ssh -i ~/.ssh/id_rsa ubuntu@<IP_PUBLIQUE>
```

## 🔧 Variables principales

- `ssh_public_key` : Votre clé SSH publique (obligatoire)
- `instance_type` : Type d'instance GPU (défaut: g4dn.xlarge)
- `aws_region` : Région AWS (défaut: eu-west-1)
- `disk_size_gb` : Taille du disque (défaut: 100GB)

## 🗑️ Nettoyage

```bash
# Supprimer toute l'infrastructure
terraform destroy
```

## 📋 Notes

- Cette configuration provisionne uniquement l'infrastructure
- Le déploiement de l'application doit être fait manuellement après connexion SSH
- L'instance est configurée avec Ubuntu 20.04 + drivers GPU
