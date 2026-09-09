variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
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
  description = "Cloudflare Zone ID for the domain"
}
