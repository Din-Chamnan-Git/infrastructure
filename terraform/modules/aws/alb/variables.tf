variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB (must be across at least 2 AZs)"
  type        = list(string)
}

variable "domain_name" {
  description = "The apex domain name managed in Cloudflare (e.g., example.com)"
  type        = string
}

variable "subdomain" {
  description = "The subdomain for the application (e.g., dev or app)"
  type        = string
  default     = "app"
}
