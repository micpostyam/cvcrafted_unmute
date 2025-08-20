# Guide de déploiement Terraform AWS pour Unmute

Ce guide vous accompagne étape par étape pour déployer Unmute sur AWS avec Terraform.

## 🎯 Prérequis

### 1. Outils nécessaires
```bash
# Installation Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Vérification
terraform --version
```

### 2. Configuration AWS CLI
```bash
# Installation AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configuration avec vos clés AWS
aws configure
# AWS Access Key ID: [Votre clé]
# AWS Secret Access Key: [Votre secret]
# Default region: eu-west-1
# Default output format: json
```

### 3. Clés et tokens nécessaires

#### Clé SSH
```bash
# Générer une clé SSH si vous n'en avez pas
ssh-keygen -t rsa -b 4096 -C "votre-email@example.com"

# Afficher votre clé publique
cat ~/.ssh/id_rsa.pub
```

#### Clé API Mistral AI
1. Allez sur https://console.mistral.ai/
2. Créez un compte
3. Générez une clé API
4. Gardez-la précieusement

#### Token Hugging Face
1. Allez sur https://huggingface.co/settings/tokens
2. Créez un compte si nécessaire
3. Générez un token de lecture
4. Gardez-le précieusement

## 🚀 Déploiement

### Étape 1 : Configuration
```bash
# Aller dans le dossier terraform
cd terraform

# Copier le fichier d'exemple
cp terraform.tfvars.example terraform.tfvars

# Éditer avec vos valeurs
nano terraform.tfvars
```

### Étape 2 : Validation
```bash
# Initialiser Terraform
terraform init

# Vérifier la configuration
terraform validate

# Voir ce qui va être créé
terraform plan
```

### Étape 3 : Déploiement
```bash
# Déployer l'infrastructure
terraform apply

# Confirmer avec "yes" quand demandé
```

### Étape 4 : Attendre et vérifier
```bash
# Attendre 5-10 minutes que tout s'installe

# Récupérer l'IP publique
terraform output instance_public_ip

# Tester l'accès SSH
ssh ubuntu@$(terraform output -raw instance_public_ip)

# Vérifier les logs d'installation
ssh ubuntu@$(terraform output -raw instance_public_ip) 'tail -f /var/log/unmute-setup.log'
```

## 🔧 Utilisation

### Accéder à l'application
```bash
# URL du frontend (remplacez IP par votre IP)
http://VOTRE_IP:3000

# URL de l'API
http://VOTRE_IP:8000

# Commandes SSH utiles
ssh ubuntu@VOTRE_IP 'cd unmute && docker-compose logs -f'  # Logs
ssh ubuntu@VOTRE_IP 'cd unmute && docker-compose ps'       # Status
ssh ubuntu@VOTRE_IP './monitor.sh'                         # Monitoring
```

### Surveillance des coûts
```bash
# Arrêter l'instance pour économiser
aws ec2 stop-instances --instance-ids $(terraform output -raw instance_id)

# Redémarrer l'instance
aws ec2 start-instances --instance-ids $(terraform output -raw instance_id)

# Vérifier les coûts dans la console AWS
# Billing & Cost Management > Cost Explorer
```

## 🛠️ Maintenance

### Mise à jour du code
```bash
# Se connecter à l'instance
ssh ubuntu@$(terraform output -raw instance_public_ip)

# Mettre à jour le code
cd unmute
git pull
docker-compose down
docker-compose up -d --build
```

### Redimensionner l'instance
```bash
# Modifier terraform.tfvars
instance_type = "g5.xlarge"  # Plus puissant

# Appliquer les changements
terraform apply
```

### Logs et debugging
```bash
# Logs de l'installation
ssh ubuntu@IP 'tail -f /var/log/unmute-setup.log'

# Logs des containers
ssh ubuntu@IP 'cd unmute && docker-compose logs -f'

# Status GPU
ssh ubuntu@IP 'nvidia-smi'

# Monitoring complet
ssh ubuntu@IP './monitor.sh'
```

## 💰 Optimisation des coûts

### 1. Instance Spot
- Utilisée par défaut
- ~70% moins cher
- Peut être interrompue par AWS

### 2. Auto-shutdown
- Configuré pour s'arrêter la nuit
- Économise ~50% si utilisation 12h/jour
- Modifiable dans `terraform.tfvars`

### 3. Surveillance
```bash
# Vérifier les coûts actuels
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## 🚨 Dépannage

### Problème : Instance Spot interrompue
```bash
# Vérifier le status
aws ec2 describe-spot-instance-requests

# Redémarrer si nécessaire
terraform apply
```

### Problème : Services ne démarrent pas
```bash
# Vérifier les logs
ssh ubuntu@IP 'cd unmute && docker-compose logs'

# Redémarrer les services
ssh ubuntu@IP 'cd unmute && docker-compose restart'

# Vérifier GPU
ssh ubuntu@IP 'nvidia-smi'
```

### Problème : Accès réseau
```bash
# Vérifier Security Group
aws ec2 describe-security-groups --group-ids $(terraform output -raw security_group_id)

# Tester les ports
telnet VOTRE_IP 3000
telnet VOTRE_IP 8000
```

## 🗑️ Nettoyage

### Supprimer tout
```bash
# Détruire l'infrastructure
terraform destroy

# Confirmer avec "yes"
```

### Garder les données
```bash
# Créer un snapshot avant destruction
aws ec2 create-snapshot --volume-id VOLUME_ID --description "Unmute backup"
```

## 📞 Support

### Logs utiles
- `/var/log/unmute-setup.log` : Installation
- `/var/log/unmute-monitoring.log` : Monitoring
- `docker-compose logs` : Applications

### Commandes de diagnostic
```bash
# Check complet du système
ssh ubuntu@IP '
  echo "=== GPU ==="
  nvidia-smi
  echo "=== Docker ==="
  docker ps
  echo "=== Disk ==="
  df -h
  echo "=== Memory ==="
  free -h
  echo "=== Network ==="
  netstat -tlnp
'
```

---

**💡 Conseil :** Commencez avec une instance `g4dn.xlarge` en Spot pour tester, puis ajustez selon vos besoins et budget !
