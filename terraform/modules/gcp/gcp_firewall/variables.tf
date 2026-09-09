variable "network_name" {
  type        = string
  description = "The name of the VPC network to apply firewall rules to"
}

variable "ip_cidr_range" {
  type        = string
  description = "Subnet range for internal communication"
}
