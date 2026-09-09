variable "network_name" {
  type        = string
  description = "this is network name global"
}

variable "subnet_name" {
  type        = string
  description = "Name of the regional subnet"
}

variable "ip_cidr_range" {
  type        = string
  description = "IP CIDR block for the subnet (e.g. 10.10.1.0/24)"
}

variable "region" {
  type        = string
  description = "The GCP region to deploy the subnet in"
}
