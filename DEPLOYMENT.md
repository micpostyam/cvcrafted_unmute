# 🚀 Pipeline de Déploiement Automatisé Unmute

Ce pipeline combine **Terraform** pour l'infrastructure et **Ansible** pour la configuration automatisée d'Unmute sur AWS.

## 📋 Vue d'ensemble

- **Infrastructure**: AWS EC2 avec GPU (g4dn.xlarge)
- **Services**: Frontend (Next.js) + Backend (FastAPI) + STT/TTS (Moshi) + Monitoring
- **Coût estimé**: ~25$/mois avec instances Spot
- **Déploiement**: Entièrement automatisé en 1 commande

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Terraform     │────│     Ansible     │────│   Application   │
│  Infrastructure │    │  Configuration  │    │    Services     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                        │                        │
        ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ • EC2 Instance  │    │ • System Setup  │    │ • Frontend:3000 │
│ • Security Grps │    │ • Docker        │    │ • Backend:8000  │
│ • SSH Keys      │    │ • NVIDIA        │    │ • STT/TTS:GPU   │
│ • VPC/Subnets   │    │ • App Deploy    │    │ • Monitoring    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛠️ Installation et Configuration

### 1. Configuration initiale

```bash
# Installation automatique des prérequis
./scripts/setup.sh

# Configuration des clés API
nano terraform/.env
```

### 2. Configuration des clés API

Éditez `terraform/.env` avec vos clés :

```bash
# AWS Configuration
TF_VAR_aws_access_key="AKIA..."
TF_VAR_aws_secret_key="..."
TF_VAR_aws_region="us-east-1"

# Application API Keys
TF_VAR_mistral_api_key="..."        # API Mistral pour le LLM
TF_VAR_hugging_face_token="..."     # Token HuggingFace pour Moshi
TF_VAR_openai_api_key="..."         # Clé OpenAI (optionnel)
```

### 3. Validation

```bash
# Valider la configuration
./scripts/setup.sh validate
```

## 🚀 Déploiement

### Déploiement complet (recommandé)

```bash
# Déploiement automatique complet
./scripts/deploy.sh

# Temps estimé: 10-15 minutes
# ✅ Infrastructure AWS provisionnée
# ✅ Instance configurée avec GPU
# ✅ Application déployée et fonctionnelle
```

### Déploiement étape par étape

```bash
# 1. Infrastructure seulement
cd terraform
terraform init
terraform plan
terraform apply

# 2. Configuration seulement
cd ../ansible
source ../ansible-env/bin/activate
ansible-playbook playbooks/deploy.yml
```

## 📊 Monitoring et Maintenance

### Monitoring rapide

```bash
# Status des services
./scripts/monitor.sh quick

# Monitoring interactif complet
./scripts/monitor.sh
```

### Accès aux services

Après déploiement, accédez aux services via :

- **Frontend**: `http://IP_INSTANCE:3000`
- **Backend API**: `http://IP_INSTANCE:8000`
- **Grafana**: `http://IP_INSTANCE:3001` (admin/admin123)
- **Prometheus**: `http://IP_INSTANCE:9090`

### Connexion SSH

```bash
ssh -i terraform/unmute-key.pem ubuntu@IP_INSTANCE
```

### Logs et debugging

```bash
# Logs des services
./scripts/monitor.sh logs

# Monitoring système
./scripts/monitor.sh system

# Monitoring continu
./scripts/monitor.sh watch
```

## 🔧 Gestion du Cycle de Vie

### Arrêt temporaire

```bash
# Via Ansible
cd ansible
ansible-playbook playbooks/undeploy.yml

# Via SSH direct
ssh -i terraform/unmute-key.pem ubuntu@IP_INSTANCE
cd /opt/unmute
docker-compose -f docker-compose.production.yml down
```

### Redémarrage

```bash
# Redéploiement application seulement
cd ansible
ansible-playbook playbooks/deploy.yml
```

### Destruction complète

```bash
# Destruction complète (infrastructure + données)
./scripts/destroy.sh

# Destruction sélective
./scripts/destroy.sh app           # Application seulement
./scripts/destroy.sh infrastructure # Infrastructure seulement
./scripts/destroy.sh local          # Fichiers locaux seulement
```

## 📁 Structure du Pipeline

```
├── scripts/
│   ├── setup.sh          # Configuration initiale
│   ├── deploy.sh         # Déploiement complet
│   ├── monitor.sh        # Monitoring et maintenance
│   └── destroy.sh        # Destruction
├── terraform/
│   ├── main.tf           # Infrastructure AWS
│   ├── variables.tf      # Variables configurables
│   ├── outputs.tf        # Outputs (IP, ID instance)
│   └── .env              # Clés API (à configurer)
├── ansible/
│   ├── ansible.cfg       # Configuration Ansible
│   ├── inventory/        # Inventaire dynamique
│   ├── group_vars/       # Variables globales
│   ├── roles/            # Rôles de configuration
│   │   ├── common/       # Configuration système de base
│   │   ├── docker/       # Installation Docker
│   │   ├── nvidia/       # Drivers NVIDIA/CUDA
│   │   └── unmute/       # Déploiement application
│   └── playbooks/        # Playbooks d'orchestration
│       ├── deploy.yml    # Déploiement principal
│       ├── undeploy.yml  # Nettoyage
│       └── monitor.yml   # Monitoring
└── ansible-env/          # Environnement virtuel Python
```

## 🔍 Troubleshooting

### Problèmes fréquents

1. **Quota AWS dépassé**
   ```bash
   # Vérifier les quotas dans la console AWS
   # Demander une augmentation si nécessaire
   ```

2. **Échec de connectivité SSH**
   ```bash
   # Vérifier les groupes de sécurité
   # Attendre que l'instance soit complètement initialisée (2-3 min)
   ./scripts/monitor.sh quick
   ```

3. **Services qui ne démarrent pas**
   ```bash
   # Vérifier les logs
   ./scripts/monitor.sh logs
   
   # Redémarrer les services
   ssh -i terraform/unmute-key.pem ubuntu@IP_INSTANCE
   cd /opt/unmute
   docker-compose -f docker-compose.production.yml restart
   ```

4. **GPU non détecté**
   ```bash
   # Vérifier l'installation NVIDIA
   ssh -i terraform/unmute-key.pem ubuntu@IP_INSTANCE
   nvidia-smi
   
   # Redéployer le rôle NVIDIA si nécessaire
   cd ansible
   ansible-playbook playbooks/deploy.yml --tags nvidia
   ```

### Logs et diagnostics

```bash
# Logs Terraform
cd terraform && terraform show

# Logs Ansible
cd ansible && cat ansible.log

# Logs application
./scripts/monitor.sh logs

# Status détaillé
./scripts/monitor.sh system
```

## 💰 Optimisation des Coûts

### Instances Spot (recommandé)

```bash
# Activer les instances Spot dans terraform/.env
TF_VAR_use_spot_instances=true

# Économie: ~70% vs instances On-Demand
# Risque: Instance peut être interrompue
```

### Arrêt programmé

```bash
# Arrêter l'instance pendant les heures creuses
# Via console AWS ou automatisation avec Lambda
```

### Monitoring des coûts

- Configurez AWS Billing Alerts
- Utilisez AWS Cost Explorer
- Surveillez l'utilisation GPU

## 🔐 Sécurité

### Bonnes pratiques

- ✅ Clés SSH générées automatiquement
- ✅ Groupes de sécurité restrictifs
- ✅ Variables d'environnement sécurisées
- ✅ Accès HTTPS pour les APIs externes

### Améliorer la sécurité

```bash
# Restreindre l'accès SSH à votre IP
# Éditer terraform/main.tf, section security_group
cidr_blocks = ["VOTRE_IP/32"]

# Utiliser un VPN ou bastion host pour la production
```

## 🤝 Contribution

Pour contribuer au pipeline :

1. Testez en local avec `./scripts/setup.sh validate`
2. Documentez les changements
3. Vérifiez la compatibilité AWS/Ansible
4. Soumettez un PR avec les tests

## 📞 Support

- 📖 Documentation complète dans `/docs`
- 🐛 Issues sur GitHub
- 💬 Discussions dans le canal technique
- 📧 Contact: équipe DevOps

---

**Temps de déploiement typique**: 10-15 minutes  
**Coût mensuel estimé**: 25-80$ selon l'utilisation  
**Uptime cible**: 99.5%  
**Support GPU**: NVIDIA T4 (16GB VRAM)**
