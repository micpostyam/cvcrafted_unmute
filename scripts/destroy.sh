#!/bin/bash
set -e

# Script de destruction complète de l'infrastructure
echo "🔥 Destruction de l'infrastructure Unmute"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TERRAFORM_DIR="./terraform"
ANSIBLE_DIR="./ansible"
ANSIBLE_ENV="ansible-env"

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

# Nettoyage de l'application via Ansible
cleanup_application() {
    log_info "Nettoyage de l'application avec Ansible..."
    
    if [ -d "$ANSIBLE_ENV" ]; then
        source "$ANSIBLE_ENV/bin/activate"
        cd "$ANSIBLE_DIR"
        
        # Vérifier si l'instance est accessible
        if ansible aws_gpu_instances -m ping &>/dev/null; then
            log_info "Instance accessible, nettoyage de l'application..."
            ansible-playbook playbooks/undeploy.yml -e "cleanup_docker_images=true" -e "cleanup_project_files=true" -e "cleanup_cache=true"
        else
            log_warning "Instance non accessible, skip du nettoyage applicatif"
        fi
        
        cd ..
        deactivate
    else
        log_warning "Environnement Ansible non trouvé, skip du nettoyage applicatif"
    fi
}

# Destruction de l'infrastructure
destroy_infrastructure() {
    log_info "Destruction de l'infrastructure AWS..."
    
    cd "$TERRAFORM_DIR"
    
    if [ -f "terraform.tfstate" ]; then
        # Charger les variables d'environnement
        if [ -f ".env" ]; then
            set -a
            source .env
            set +a
        fi
        
        # Afficher ce qui va être détruit
        log_info "Planification de la destruction..."
        terraform plan -destroy
        
        # Demander confirmation
        echo ""
        log_warning "⚠️  ATTENTION: Cette action va détruire TOUTE l'infrastructure AWS!"
        log_warning "- Instance EC2"
        log_warning "- Clé SSH"
        log_warning "- Groupes de sécurité"
        log_warning "- Toutes les données sur l'instance"
        echo ""
        
        read -p "Êtes-vous ABSOLUMENT sûr de vouloir continuer? Tapez 'yes' pour confirmer: " confirm
        
        if [ "$confirm" = "yes" ]; then
            log_info "Destruction en cours..."
            terraform destroy -auto-approve
            log_success "Infrastructure détruite"
            
            # Nettoyer les fichiers temporaires
            rm -f tfplan
            rm -f unmute-key.pem
        else
            log_info "Destruction annulée"
            exit 0
        fi
    else
        log_warning "Aucune infrastructure trouvée à détruire"
    fi
    
    cd ..
}

# Nettoyage local
cleanup_local() {
    log_info "Nettoyage des fichiers locaux..."
    
    # Nettoyer les artefacts Terraform
    cd "$TERRAFORM_DIR"
    rm -f tfplan
    rm -f unmute-key.pem
    rm -f .terraform.lock.hcl
    rm -rf .terraform/
    cd ..
    
    # Option de nettoyer l'environnement virtuel
    if [ -d "$ANSIBLE_ENV" ]; then
        read -p "Voulez-vous aussi supprimer l'environnement virtuel Ansible? (y/n): " cleanup_venv
        if [ "$cleanup_venv" = "y" ]; then
            rm -rf "$ANSIBLE_ENV"
            log_success "Environnement virtuel supprimé"
        fi
    fi
    
    log_success "Nettoyage local terminé"
}

# Fonction principale
main() {
    case "${1:-full}" in
        "app")
            log_info "Nettoyage de l'application uniquement..."
            cleanup_application
            ;;
        "infrastructure"|"infra")
            log_info "Destruction de l'infrastructure uniquement..."
            destroy_infrastructure
            ;;
        "local")
            log_info "Nettoyage local uniquement..."
            cleanup_local
            ;;
        "full")
            log_info "Destruction complète..."
            cleanup_application
            destroy_infrastructure
            cleanup_local
            ;;
        *)
            echo "Usage: $0 [app|infrastructure|local|full]"
            echo "  app            - Nettoyer l'application uniquement"
            echo "  infrastructure - Détruire l'infrastructure AWS uniquement"
            echo "  local          - Nettoyer les fichiers locaux uniquement"
            echo "  full           - Destruction complète (défaut)"
            exit 1
            ;;
    esac
    
    echo ""
    log_success "🎉 Destruction terminée!"
    echo ""
    log_info "Pour redéployer:"
    echo "  ./scripts/deploy.sh"
}

main "$@"
