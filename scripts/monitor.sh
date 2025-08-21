#!/bin/bash
set -e

# Script de monitoring Unmute
echo "🔍 Monitoring Unmute - $(date)"

# Couleurs
GREEN='\033[0;32m'
RED='\033[0;31m'
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

# Récupérer l'IP de l'instance
get_instance_ip() {
    cd "$TERRAFORM_DIR"
    if [ -f "terraform.tfstate" ]; then
        INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
        if [ -z "$INSTANCE_IP" ]; then
            log_error "Impossible de récupérer l'IP de l'instance"
            exit 1
        fi
    else
        log_error "Aucune infrastructure déployée trouvée"
        exit 1
    fi
    cd ..
}

# Monitoring local via Ansible
monitor_via_ansible() {
    log_info "Monitoring via Ansible..."
    
    source "$ANSIBLE_ENV/bin/activate"
    cd "$ANSIBLE_DIR"
    
    ansible-playbook playbooks/monitor.yml
    
    cd ..
    deactivate
}

# Monitoring direct via SSH
monitor_direct() {
    log_info "Monitoring direct via SSH..."
    
    # Test de connectivité de base
    echo "🌐 Test de connectivité:"
    ping -c 3 "$INSTANCE_IP" > /dev/null && log_success "Ping OK" || log_error "Ping KO"
    
    # Test des ports
    echo ""
    echo "🔌 Test des ports:"
    for port in 3000 8000 3001 9090; do
        if nc -z -w5 "$INSTANCE_IP" "$port" 2>/dev/null; then
            log_success "Port $port: OUVERT"
        else
            log_error "Port $port: FERMÉ"
        fi
    done
    
    # Test HTTP des services
    echo ""
    echo "🌍 Test HTTP des services:"
    
    # Frontend
    if curl -s -o /dev/null -w "%{http_code}" "http://$INSTANCE_IP:3000" | grep -q "200\|301\|302"; then
        log_success "Frontend (3000): OK"
    else
        log_error "Frontend (3000): KO"
    fi
    
    # Backend
    if curl -s -o /dev/null -w "%{http_code}" "http://$INSTANCE_IP:8000/health" | grep -q "200"; then
        log_success "Backend (8000): OK"
    else
        log_error "Backend (8000): KO"
    fi
    
    # Grafana
    if curl -s -o /dev/null -w "%{http_code}" "http://$INSTANCE_IP:3001" | grep -q "200\|302"; then
        log_success "Grafana (3001): OK"
    else
        log_error "Grafana (3001): KO"
    fi
    
    # Prometheus
    if curl -s -o /dev/null -w "%{http_code}" "http://$INSTANCE_IP:9090" | grep -q "200"; then
        log_success "Prometheus (9090): OK"
    else
        log_error "Prometheus (9090): KO"
    fi
}

# Affichage des informations système via SSH
system_info() {
    log_info "Informations système..."
    
    ssh -i "$TERRAFORM_DIR/unmute-key.pem" -o StrictHostKeyChecking=no ubuntu@"$INSTANCE_IP" << 'EOF'
echo "🖥️ Système:"
uname -a
echo ""

echo "💾 Espace disque:"
df -h
echo ""

echo "🧠 Mémoire:"
free -h
echo ""

echo "🔧 GPU (si disponible):"
nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "GPU non disponible"
echo ""

echo "🐳 Conteneurs Docker:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF
}

# Logs des services
service_logs() {
    log_info "Logs des services (dernières 20 lignes)..."
    
    ssh -i "$TERRAFORM_DIR/unmute-key.pem" -o StrictHostKeyChecking=no ubuntu@"$INSTANCE_IP" << 'EOF'
cd /opt/unmute
echo "📝 Backend logs:"
docker-compose -f docker-compose.production.yml logs --tail=20 backend
echo ""

echo "📝 Frontend logs:"
docker-compose -f docker-compose.production.yml logs --tail=20 frontend
echo ""

echo "📝 STT logs:"
docker-compose -f docker-compose.production.yml logs --tail=20 stt
EOF
}

# Menu principal
show_menu() {
    echo ""
    echo "📊 Options de monitoring:"
    echo "1. Status rapide (ports + HTTP)"
    echo "2. Monitoring complet via Ansible"
    echo "3. Informations système"
    echo "4. Logs des services"
    echo "5. Monitoring continu (watch)"
    echo "q. Quitter"
    echo ""
}

# Monitoring continu
continuous_monitor() {
    log_info "Monitoring continu (Ctrl+C pour arrêter)..."
    
    while true; do
        clear
        echo "🔄 Monitoring continu - $(date)"
        echo "Instance: $INSTANCE_IP"
        echo "================================"
        monitor_direct
        echo ""
        echo "Prochaine vérification dans 30s..."
        sleep 30
    done
}

# Fonction principale
main() {
    get_instance_ip
    log_success "Instance trouvée: $INSTANCE_IP"
    
    if [ $# -eq 0 ]; then
        # Mode interactif
        while true; do
            show_menu
            read -p "Votre choix: " choice
            case $choice in
                1) monitor_direct ;;
                2) monitor_via_ansible ;;
                3) system_info ;;
                4) service_logs ;;
                5) continuous_monitor ;;
                q|Q) exit 0 ;;
                *) log_warning "Option invalide" ;;
            esac
            echo ""
            read -p "Appuyez sur Entrée pour continuer..."
        done
    else
        # Mode commande directe
        case "$1" in
            "quick") monitor_direct ;;
            "ansible") monitor_via_ansible ;;
            "system") system_info ;;
            "logs") service_logs ;;
            "watch") continuous_monitor ;;
            *) 
                echo "Usage: $0 [quick|ansible|system|logs|watch]"
                echo "  quick   - Test rapide des ports et HTTP"
                echo "  ansible - Monitoring complet via Ansible"
                echo "  system  - Informations système"
                echo "  logs    - Logs des services"
                echo "  watch   - Monitoring continu"
                exit 1
                ;;
        esac
    fi
}

main "$@"
