# Outputs Terraform - Informations utiles après le déploiement

output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.unmute.id
}

output "public_ip" {
  description = "Adresse IP publique de l'instance"
  value       = aws_eip.unmute.public_ip
}

output "ssh_command" {
  description = "Commande SSH pour se connecter à l'instance"
  value       = "ssh -i ~/unmute_key ubuntu@${aws_eip.unmute.public_ip}"
}

output "instance_type" {
  description = "Type d'instance utilisé"
  value       = aws_instance.unmute.instance_type
}

output "vpc_id" {
  description = "ID du VPC créé"
  value       = aws_vpc.unmute.id
}

output "security_group_id" {
  description = "ID du groupe de sécurité"
  value       = aws_security_group.unmute.id
}
