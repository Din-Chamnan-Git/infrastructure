output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "AWS DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_security_group_id" {
  description = "Security Group ID of the ALB"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the Target Group to attach EC2 instances or Auto Scaling Groups"
  value       = aws_lb_target_group.web.arn
}

output "app_url" {
  description = "Full HTTPS URL of the application via Cloudflare"
  value       = "https://${var.subdomain}.${var.domain_name}"
}
