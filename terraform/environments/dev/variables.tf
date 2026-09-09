variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.10.0.0/16"
  description = "VPC CIDR block"
}

variable "subnet_cidr" {
  type        = string
  default     = "10.10.1.0/24"
  description = "Public Subnet CIDR block"
}

variable "availability_zone" {
  type        = string
  default     = "us-east-1a"
  description = "Availability zone"
}

variable "master_nodes" {
  type = map(object({
    instance_type = string
    disk_size_gb  = number
    role          = string
  }))
  description = "Master nodes map"
}

variable "worker_nodes" {
  type = map(object({
    instance_type = string
    disk_size_gb  = number
    role          = string
  }))
  description = "Worker nodes map"
}

variable "public_key_path" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Path to SSH public key file"
}

variable "subnet_2_cidr" {
  type        = string
  default     = "10.10.2.0/24"
  description = "Second Public Subnet CIDR block"
}

variable "subnet_2_availability_zone" {
  type        = string
  default     = "us-east-1b"
  description = "Second Availability zone"
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token with DNS edit permissions"
}

variable "domain_name" {
  type        = string
  description = "The root domain managed in Cloudflare (e.g. example.com)"
}

variable "subdomain" {
  type        = string
  default     = "app"
  description = "The subdomain for the application"
}
