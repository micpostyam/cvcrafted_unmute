#!/bin/bash
set -e

# Script de déploiement complet Terraform + Ansible
echo "🚀 Démarrage du déploiement Unmute sur AWS"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="./terraform"
ANSIBLE_DIR="./ansible"
ANSIBLE_ENV="ansible-env"

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifications préalables
check_prerequisites() {
    log_info "Vérification des prérequis..."
    
    # Vérifier Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform n'est pas installé"
        exit 1
    fi
    
    # Vérifier Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 n'est pas installé"
        exit 1
    fi
    
    # Vérifier l'environnement virtuel Ansible
    if [ ! -d "$ANSIBLE_ENV" ]; then
        log_error "L'environnement virtuel Ansible n'existe pas. Exécutez: python3 -m venv $ANSIBLE_ENV && source $ANSIBLE_ENV/bin/activate && pip install ansible[aws]"
        exit 1
    fi
    
    # Vérifier les variables d'environnement
    if [ ! -f "$TERRAFORM_DIR/.env" ]; then
        log_error "Le fichier $TERRAFORM_DIR/.env n'existe pas"
        exit 1
    fi
    
    log_success "Prérequis validés"
}

# Déploiement de l'infrastructure avec Terraform
deploy_infrastructure() {
    log_info "Déploiement de l'infrastructure AWS avec Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Charger les variables d'environnement
    set -a
    source .env
    set +a
    
    # Initialiser Terraform
    log_info "Initialisation de Terraform..."
    terraform init
    
    # Planifier le déploiement
    log_info "Planification du déploiement..."
    terraform plan -out=tfplan
    
    # Demander confirmation
    read -p "Voulez-vous appliquer ce plan? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_warning "Déploiement annulé"
        exit 0
    fi
    
    # Appliquer le plan
    log_info "Application du plan Terraform..."
    terraform apply tfplan
    
    # Récupérer les outputs
    INSTANCE_IP=$(terraform output -raw instance_public_ip)
    INSTANCE_ID=$(terraform output -raw instance_id)
    
    log_success "Infrastructure déployée - IP: $INSTANCE_IP"
    
    cd ..
    
    # Exporter les variables pour Ansible
    export UNMUTE_SERVER_IP="$INSTANCE_IP"
    export UNMUTE_INSTANCE_ID="$INSTANCE_ID"
}

# Configuration et déploiement avec Ansible
deploy_application() {
    log_info "Configuration de l'application avec Ansible..."
    
    # Activer l'environnement virtuel
    source "$ANSIBLE_ENV/bin/activate"
    
    cd "$ANSIBLE_DIR"
    
    # Attendre que l'instance soit prête
    log_info "Attente que l'instance soit prête..."
    sleep 60
    
    # Tester la connectivité SSH
    log_info "Test de la connectivité SSH..."
    max_attempts=10
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ansible aws_gpu_instances -m ping; then
            log_success "Connectivité SSH établie"
            break
        else
            log_warning "Tentative $attempt/$max_attempts - Retry dans 30s..."
            sleep 30
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Impossible d'établir la connectivité SSH"
        exit 1
    fi
    
    # Déployer l'application
    log_info "Déploiement de l'application Unmute..."
    ansible-playbook playbooks/deploy.yml -v
    
    cd ..
    deactivate
}

# Affichage des informations finales
display_final_info() {
    cd "$TERRAFORM_DIR"
    INSTANCE_IP=$(terraform output -raw instance_public_ip)
    cd ..
    
    log_success "🎉 Déploiement terminé avec succès!"
    echo ""
    echo "📋 Informations d'accès:"
    echo "🌐 Frontend: http://$INSTANCE_IP:3000"
    echo "🔧 Backend: http://$INSTANCE_IP:8000"
    echo "📊 Grafana: http://$INSTANCE_IP:3001 (admin/admin123)"
    echo "📈 Prometheus: http://$INSTANCE_IP:9090"
    echo ""
    echo "🔑 Connexion SSH:"
    echo "ssh -i terraform/unmute-key.pem ubuntu@$INSTANCE_IP"
    echo ""
    echo "📝 Commandes utiles:"
    echo "- Monitoring: ./scripts/monitor.sh"
    echo "- Destruction: ./scripts/destroy.sh"
}

# Gestion des erreurs
handle_error() {
    log_error "Une erreur s'est produite. Nettoyage en cours..."
    
    # Optionnel: nettoyer les ressources partiellement créées
    # cd "$TERRAFORM_DIR" && terraform destroy -auto-approve
    
    exit 1
}

# Configuration du trap pour gérer les erreurs
trap handle_error ERR

# Exécution principale
main() {
    check_prerequisites
    deploy_infrastructure
    deploy_application
    display_final_info
}

# Gestion des arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "check")
        check_prerequisites
        log_success "Prérequis OK"
        ;;
    *)
        echo "Usage: $0 [deploy|check]"
        echo "  deploy  - Déploiement complet (défaut)"
        echo "  check   - Vérification des prérequis uniquement"
        exit 1
        ;;
esac
