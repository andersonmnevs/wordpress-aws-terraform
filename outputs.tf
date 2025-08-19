output "wordpress_url" {
  description = "URL do WordPress"
  value       = "http://${aws_lb.main.dns_name}"
}

output "wordpress_admin_url" {
  description = "URL do admin WordPress"
  value       = "http://${aws_lb.main.dns_name}/wp-admin/"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "health_check_url" {
  description = "Health check URL"
  value       = "http://${aws_lb.main.dns_name}/health"
}

output "database_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "efs_id" {
  description = "EFS File System ID"
  value       = aws_efs_file_system.main.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "cost_estimate" {
  description = "Estimativa de custo mensal"
  value       = "~$35-45 USD/mês (t3.micro + db.t3.micro + EFS + ALB)"
}