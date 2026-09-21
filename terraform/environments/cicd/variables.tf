variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type    = string
  default = "asia-southeast1"
}

variable "zone" {
  type    = string
  default = "asia-southeast1-a"
}

variable "machine_type" {
  type        = string
  description = "GCP Machine Type for CI/CD Server (Jenkins, SonarQube, Nexus)"
  default     = "e2-standard-4"
}

variable "public_key_path" {
  type        = string
  description = "Path to the SSH public key file"
  default     = "/home/nan/.ssh/nan-laptop.pub"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API Token with DNS Zone Edit permissions"
  sensitive   = true
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for domain management"
}

variable "base_domain" {
  type        = string
  description = "Base domain name for CI/CD subdomains"
  default     = "dnan.tech"
}
