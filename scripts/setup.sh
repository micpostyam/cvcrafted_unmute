#!/bin/bash
set -e

# Script de configuration initiale pour Unmute
echo "⚙️ Configuration initiale de l'environnement Unmute"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Vérification des prérequis système
check_system_requirements() {
    log_info "Vérification des prérequis système..."
    
    # Vérifier Python 3
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 n'est pas installé"
        log_info "Installez Python 3: sudo apt update && sudo apt install python3 python3-venv python3-pip"
        exit 1
    fi
    
    # Vérifier Terraform
    if ! command -v terraform &> /dev/null; then
        log_warning "Terraform n'est pas installé"
        log_info "Installation de Terraform..."
        
        # Installation de Terraform
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install terraform
        
        log_success "Terraform installé"
    fi
    
    # Vérifier AWS CLI (optionnel mais recommandé)
    if ! command -v aws &> /dev/null; then
        log_warning "AWS CLI n'est pas installé (optionnel)"
        log_info "Pour l'installer: sudo apt install awscli"
    fi
    
    log_success "Prérequis système validés"
}

# Configuration de l'environnement virtuel Python
setup_python_environment() {
    log_info "Configuration de l'environnement virtuel Python..."
    
    if [ ! -d "ansible-env" ]; then
        python3 -m venv ansible-env
        log_success "Environnement virtuel créé"
    fi
    
    source ansible-env/bin/activate
    
    # Installer Ansible et ses dépendances
    pip install --upgrade pip
    pip install ansible
    pip install boto3 botocore
    
    # Installer les collections Ansible nécessaires
    ansible-galaxy collection install amazon.aws
    ansible-galaxy collection install community.docker
    
    deactivate
    log_success "Environnement Python configuré"
}

# Configuration des clés API
setup_api_keys() {
    log_info "Configuration des clés API..."
    
    if [ ! -f "terraform/.env" ]; then
        log_info "Création du fichier terraform/.env..."
        
        cat > terraform/.env << 'EOF'
# AWS Configuration
TF_VAR_aws_access_key=""
TF_VAR_aws_secret_key=""
TF_VAR_aws_region="us-east-1"

# Application API Keys
TF_VAR_mistral_api_key=""
TF_VAR_hugging_face_token=""
TF_VAR_openai_api_key=""

# Instance Configuration
TF_VAR_instance_type="g4dn.xlarge"
TF_VAR_use_spot_instances=false
EOF
        
        log_warning "Veuillez éditer terraform/.env avec vos clés API"
        log_info "Éditeur: nano terraform/.env"
    else
        log_success "Fichier terraform/.env existe déjà"
    fi
}

# Validation de la configuration
validate_configuration() {
    log_info "Validation de la configuration..."
    
    # Vérifier que le fichier .env est configuré
    source terraform/.env
    
    if [ -z "$TF_VAR_aws_access_key" ] || [ -z "$TF_VAR_aws_secret_key" ]; then
        log_warning "Les clés AWS ne sont pas configurées dans terraform/.env"
        return 1
    fi
    
    if [ -z "$TF_VAR_mistral_api_key" ]; then
        log_warning "La clé API Mistral n'est pas configurée"
        return 1
    fi
    
    if [ -z "$TF_VAR_hugging_face_token" ]; then
        log_warning "Le token Hugging Face n'est pas configuré"
        return 1
    fi
    
    log_success "Configuration validée"
    return 0
}

# Affichage du guide de démarrage
show_getting_started() {
    echo ""
    log_success "🎉 Configuration initiale terminée!"
    echo ""
    echo "📋 Prochaines étapes:"
    echo ""
    echo "1️⃣ Configurer vos clés API:"
    echo "   nano terraform/.env"
    echo ""
    echo "2️⃣ Valider la configuration:"
    echo "   ./scripts/setup.sh validate"
    echo ""
    echo "3️⃣ Déployer l'application:"
    echo "   ./scripts/deploy.sh"
    echo ""
    echo "📖 Documentation:"
    echo "   - README.md pour les détails du projet"
    echo "   - terraform/README.md pour la configuration AWS"
    echo ""
    echo "🔧 Commandes utiles:"
    echo "   - Monitoring: ./scripts/monitor.sh"
    echo "   - Destruction: ./scripts/destroy.sh"
    echo ""
}

# Test de connectivité AWS
test_aws_connectivity() {
    log_info "Test de connectivité AWS..."
    
    source terraform/.env
    
    # Tester via Terraform
    cd terraform
    if terraform init && terraform validate; then
        log_success "Configuration Terraform valide"
    else
        log_error "Problème avec la configuration Terraform"
        cd ..
        return 1
    fi
    cd ..
    
    # Tester via AWS CLI si disponible
    if command -v aws &> /dev/null; then
        export AWS_ACCESS_KEY_ID="$TF_VAR_aws_access_key"
        export AWS_SECRET_ACCESS_KEY="$TF_VAR_aws_secret_key"
        export AWS_DEFAULT_REGION="$TF_VAR_aws_region"
        
        if aws sts get-caller-identity &> /dev/null; then
            log_success "Connectivité AWS confirmée"
        else
            log_error "Échec de connexion à AWS"
            return 1
        fi
        
        unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION
    fi
    
    log_success "Tests de connectivité réussis"
}

# Fonction principale
main() {
    case "${1:-setup}" in
        "setup")
            check_system_requirements
            setup_python_environment
            setup_api_keys
            show_getting_started
            ;;
        "validate")
            if validate_configuration; then
                test_aws_connectivity
                log_success "✅ Configuration complètement validée - Prêt pour le déploiement!"
            else
                log_error "❌ Configuration incomplète - Vérifiez terraform/.env"
                exit 1
            fi
            ;;
        "requirements")
            check_system_requirements
            ;;
        "python")
            setup_python_environment
            ;;
        "keys")
            setup_api_keys
            ;;
        *)
            echo "Usage: $0 [setup|validate|requirements|python|keys]"
            echo "  setup        - Configuration complète (défaut)"
            echo "  validate     - Validation de la configuration"
            echo "  requirements - Vérification des prérequis système"
            echo "  python       - Configuration de l'environnement Python"
            echo "  keys         - Configuration des clés API"
            exit 1
            ;;
    esac
}

main "$@"
