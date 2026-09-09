variable "vpc_id" {
  type        = string
  description = "VPC ID passed from the VPC module"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod)"
}
