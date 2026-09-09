variable "security_group_id" {
  type        = string
  description = "Security Group ID passed from SG module"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID passed from the VPC module"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

variable "nodes" {
  type = map(object({
    instance_type = string
    disk_size_gb  = number
    role          = string # "master" or "worker"
  }))
  description = "Map of nodes to provision (e.g. master-1, worker-1, worker-2)"
}

variable "key_name" {
  type        = string
  description = "The name of the SSH key pair to use for EC2 instances"
}
