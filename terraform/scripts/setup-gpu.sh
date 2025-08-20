#!/bin/bash
# Script d'initialisation automatique pour l'instance GPU
# Ce script s'exécute au premier démarrage de l'instance

set -e  # Arrêter en cas d'erreur
exec > >(tee -a /var/log/unmute-setup.log)  # Logger toute la sortie
exec 2>&1

echo "==================================="
echo "🚀 Début de l'installation Unmute"
echo "==================================="

# Mise à jour du système
echo "📦 Mise à jour du système..."
apt-get update
apt-get upgrade -y

# Installation des dépendances de base
echo "🛠️ Installation des outils de base..."
apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    htop \
    tree \
    jq

# ============================================
# INSTALLATION DRIVERS NVIDIA + CUDA
# ============================================

echo "🖥️ Installation des drivers NVIDIA..."

# Ajout du repository NVIDIA
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb
dpkg -i cuda-keyring_1.0-1_all.deb

# Installation des drivers
apt-get update
apt-get -y install \
    cuda-drivers-530 \
    nvidia-container-toolkit

# Vérification de l'installation
nvidia-smi || echo "⚠️ nvidia-smi pas encore disponible, redémarrage requis"

# ============================================
# INSTALLATION DOCKER
# ============================================

echo "🐳 Installation de Docker..."

# Installation Docker via script officiel
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Ajout de l'utilisateur ubuntu au groupe docker
usermod -aG docker ubuntu

# Installation Docker Compose
echo "📦 Installation de Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configuration Docker pour GPU
cat > /etc/docker/daemon.json << EOF
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF

# Redémarrage Docker
systemctl restart docker
systemctl enable docker

# ============================================
# INSTALLATION NODE.JS (pour le frontend)
# ============================================

echo "📱 Installation de Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Installation de pnpm (plus rapide que npm)
npm install -g pnpm

# ============================================
# INSTALLATION PYTHON + UV (pour le backend)
# ============================================

echo "🐍 Installation de Python et uv..."
apt-get install -y python3 python3-pip
curl -LsSf https://astral.sh/uv/install.sh | sh

# ============================================
# CONFIGURATION DU PROJET
# ============================================

echo "📂 Clonage du projet depuis GitHub..."
cd /home/ubuntu

# Clone du repository (remplacer par votre fork)
git clone https://github.com/${github_repo}.git unmute || {
    echo "⚠️ Erreur lors du clone. Utilisation du repo par défaut..."
    git clone https://github.com/kyutai-labs/moshi.git unmute
}

cd unmute
chown -R ubuntu:ubuntu /home/ubuntu/unmute

# Configuration des variables d'environnement
echo "⚙️ Configuration de l'environnement..."
cat > .env << EOF
# Configuration Unmute
NODE_ENV=production
ENVIRONMENT=${environment}

# URLs des services (communication interne Docker)
KYUTAI_STT_URL=ws://stt:8080
KYUTAI_TTS_URL=ws://tts:8080

# API LLM externe (Mistral AI)
KYUTAI_LLM_URL=https://api.mistral.ai/v1
KYUTAI_LLM_MODEL=mistral-small-latest
KYUTAI_LLM_API_KEY=${mistral_api_key}

# Token Hugging Face pour les modèles
HUGGING_FACE_HUB_TOKEN=${hugging_face_token}

# Configuration réseau
HOST=0.0.0.0
FRONTEND_PORT=3000
BACKEND_PORT=8000

# Configuration GPU
CUDA_VISIBLE_DEVICES=0
NVIDIA_VISIBLE_DEVICES=all
EOF

# ============================================
# DOCKER COMPOSE OPTIMISÉ
# ============================================

echo "🐳 Création du fichier Docker Compose..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Frontend Next.js
  frontend:
    build: 
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - NEXT_PUBLIC_API_URL=http://localhost:8000
    depends_on:
      - backend
    restart: unless-stopped

  # Backend FastAPI
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      - KYUTAI_STT_URL=ws://stt:8080
      - KYUTAI_TTS_URL=ws://tts:8080
      - KYUTAI_LLM_URL=${KYUTAI_LLM_URL}
      - KYUTAI_LLM_API_KEY=${KYUTAI_LLM_API_KEY}
    depends_on:
      - stt
      - tts
    restart: unless-stopped

  # Service STT (Speech-to-Text)
  stt:
    build:
      context: services/moshi-server
      dockerfile: public.Dockerfile
    ports:
      - "8080:8080"
    command: ["worker", "--config", "configs/stt.toml"]
    environment:
      - HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN}
      - CUDA_VISIBLE_DEVICES=0
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped

  # Service TTS (Text-to-Speech)
  tts:
    build:
      context: services/moshi-server
      dockerfile: public.Dockerfile
    ports:
      - "8081:8080"
    command: ["worker", "--config", "configs/tts.toml"]
    environment:
      - HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN}
      - CUDA_VISIBLE_DEVICES=0
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped
EOF

# ============================================
# SERVICE SYSTEMD POUR AUTO-START
# ============================================

echo "🔧 Configuration du service auto-start..."
cat > /etc/systemd/system/unmute.service << EOF
[Unit]
Description=Unmute Application
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/unmute
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=ubuntu
Group=ubuntu
Environment=PATH=/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

# Activation du service
systemctl enable unmute.service

# ============================================
# MONITORING ET LOGS
# ============================================

echo "📊 Configuration du monitoring..."

# Script de monitoring simple
cat > /home/ubuntu/monitor.sh << 'EOF'
#!/bin/bash
echo "=== Status Unmute $(date) ==="
echo "🖥️ GPU Status:"
nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits

echo -e "\n🐳 Docker Status:"
docker-compose -f /home/ubuntu/unmute/docker-compose.yml ps

echo -e "\n💾 Disk Usage:"
df -h /

echo -e "\n🔧 Memory Usage:"
free -h

echo -e "\n📡 Network:"
curl -s http://localhost:3000 > /dev/null && echo "Frontend: ✅ OK" || echo "Frontend: ❌ KO"
curl -s http://localhost:8000/health > /dev/null && echo "Backend: ✅ OK" || echo "Backend: ❌ KO"
EOF

chmod +x /home/ubuntu/monitor.sh
chown ubuntu:ubuntu /home/ubuntu/monitor.sh

# Cron job pour monitoring toutes les heures
echo "0 * * * * /home/ubuntu/monitor.sh >> /var/log/unmute-monitoring.log 2>&1" | crontab -u ubuntu -

# ============================================
# AUTO-SHUTDOWN (si activé)
# ============================================

if [[ "${enable_auto_shutdown}" == "true" ]]; then
    echo "⏰ Configuration de l'arrêt automatique..."
    
    # Script d'arrêt
    cat > /home/ubuntu/auto-shutdown.sh << 'EOF'
#!/bin/bash
echo "$(date): Arrêt automatique programmé" >> /var/log/auto-shutdown.log
/usr/local/bin/docker-compose -f /home/ubuntu/unmute/docker-compose.yml down
/usr/bin/aws ec2 stop-instances --instance-ids $(curl -s http://169.254.169.254/latest/meta-data/instance-id) --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)
EOF
    
    chmod +x /home/ubuntu/auto-shutdown.sh
    
    # Ajout au crontab pour arrêt automatique
    shutdown_hour=$(echo "${shutdown_time}" | cut -d: -f1)
    shutdown_minute=$(echo "${shutdown_time}" | cut -d: -f2)
    echo "$shutdown_minute $shutdown_hour * * * /home/ubuntu/auto-shutdown.sh" | crontab -u ubuntu -
fi

# ============================================
# PREMIER DÉMARRAGE
# ============================================

echo "🚀 Premier démarrage des services..."

# Redémarrage pour activer les drivers NVIDIA
echo "🔄 Redémarrage programmé dans 30 secondes pour activer les drivers GPU..."
sleep 30

# Démarrage des services
cd /home/ubuntu/unmute
sudo -u ubuntu docker-compose up -d

echo "==================================="
echo "✅ Installation terminée !"
echo "==================================="
echo "📝 Logs disponibles dans :"
echo "   - /var/log/unmute-setup.log"
echo "   - /var/log/unmute-monitoring.log"
echo ""
echo "🌐 Accès :"
echo "   - Frontend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):3000"
echo "   - Backend: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000"
echo ""
echo "🔧 Commandes utiles :"
echo "   - Logs: docker-compose logs -f"
echo "   - Status: ./monitor.sh"
echo "   - Restart: docker-compose restart"
echo "==================================="

# Redémarrage final pour s'assurer que tout fonctionne
shutdown -r +1 "Redémarrage automatique dans 1 minute pour finaliser l'installation GPU"
