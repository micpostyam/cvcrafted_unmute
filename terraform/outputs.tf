# Outputs Terraform - Informations importantes après déploiement
# Ces valeurs seront affichées à la fin du déploiement

# ============================================
# INFORMATIONS DE CONNEXION
# ============================================

output "instance_public_ip" {
  description = "Adresse IP publique de l'instance (pour SSH et accès web)"
  value       = aws_eip.unmute.public_ip
}

output "instance_public_dns" {
  description = "Nom DNS public de l'instance"
  value       = aws_eip.unmute.public_dns
}

output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_spot_instance_request.unmute.spot_instance_id
}

# ============================================
# URLS D'ACCÈS À L'APPLICATION
# ============================================

output "frontend_url" {
  description = "URL pour accéder au frontend de l'application"
  value       = "http://${aws_eip.unmute.public_ip}:3000"
}

output "backend_api_url" {
  description = "URL de l'API backend"
  value       = "http://${aws_eip.unmute.public_ip}:8000"
}

output "websocket_url" {
  description = "URL WebSocket pour la communication temps réel"
  value       = "ws://${aws_eip.unmute.public_ip}:8000/ws"
}

# ============================================
# COMMANDES UTILES
# ============================================

output "ssh_command" {
  description = "Commande SSH pour se connecter à l'instance"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.unmute.public_ip}"
}

output "docker_logs_command" {
  description = "Commande pour voir les logs Docker"
  value       = "ssh ubuntu@${aws_eip.unmute.public_ip} 'cd unmute && docker-compose logs -f'"
}

output "restart_services_command" {
  description = "Commande pour redémarrer les services"
  value       = "ssh ubuntu@${aws_eip.unmute.public_ip} 'cd unmute && docker-compose restart'"
}

# ============================================
# INFORMATIONS DE COÛT
# ============================================

output "estimated_monthly_cost" {
  description = "Coût estimé mensuel (en USD)"
  value = {
    spot_instance = "~$30-40 (avec g4dn.xlarge spot)"
    storage      = "~$5-10 (disque EBS)"
    network      = "~$2-5 (transfert données)"
    total        = "~$37-55/mois"
  }
}

# ============================================
# CONFIGURATION RÉSEAU
# ============================================

output "vpc_id" {
  description = "ID du VPC créé"
  value       = aws_vpc.unmute.id
}

output "subnet_id" {
  description = "ID du sous-réseau public"
  value       = aws_subnet.unmute_public.id
}

output "security_group_id" {
  description = "ID du groupe de sécurité"
  value       = aws_security_group.unmute.id
}

# ============================================
# STATUS ET MONITORING
# ============================================

output "instance_state" {
  description = "État actuel de l'instance"
  value       = aws_spot_instance_request.unmute.instance_state
}

output "spot_instance_state" {
  description = "État de la demande Spot"
  value       = aws_spot_instance_request.unmute.spot_request_state
}

# ============================================
# INSTRUCTIONS APRÈS DÉPLOIEMENT
# ============================================

output "next_steps" {
  description = "Prochaines étapes après le déploiement"
  value = <<-EOT
    🎉 Déploiement terminé avec succès !
    
    📋 Prochaines étapes :
    
    1. Attendez 5-10 minutes que les services se lancent
    
    2. Vérifiez les logs :
       ${chomp("ssh ubuntu@${aws_eip.unmute.public_ip} 'cd unmute && docker-compose logs -f'")}
    
    3. Accédez à l'application :
       Frontend: http://${aws_eip.unmute.public_ip}:3000
       API: http://${aws_eip.unmute.public_ip}:8000
    
    4. Surveillez les coûts dans la console AWS
    
    5. Pour arrêter l'instance et économiser :
       aws ec2 stop-instances --instance-ids ${aws_spot_instance_request.unmute.spot_instance_id}
    
    ⚠️  Rappel : L'instance Spot peut être interrompue par AWS si la demande est forte.
    
    📚 Documentation complète : https://github.com/votre-repo/unmute
  EOT
}
