output "wordpress_url" {
  description = "URL do WordPress (HTTP)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "wordpress_admin_url" {
  description = "URL do admin WordPress (HTTP)"
  value       = "http://${aws_lb.main.dns_name}/wp-admin/"
}

output "wordpress_url_http" {
  description = "WordPress website URL (HTTP)"
  value       = "http://${var.domain_name}"
}

output "wordpress_www_url_http" {
  description = "WordPress website URL with www (HTTP)"
  value       = "http://www.${var.domain_name}"
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
  value       = "~$30-35 USD/mês (t3.micro + db.t3.micro + EFS + ALB - sem Route53)"
}

output "acm_validation_records" {
  description = "Registros DNS para validação manual do ACM"
  value = [
    for dvo in aws_acm_certificate.main.domain_validation_options : {
      domain = dvo.domain_name
      name   = trimsuffix(dvo.resource_record_name, ".viposa.com.br.")
      type   = dvo.resource_record_type
      value  = trimsuffix(dvo.resource_record_value, ".")
    }
  ]
}