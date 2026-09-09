variable "zone" {
  type        = string
  description = "The GCP zone to deploy VM instances"
}

variable "subnet_name" {
  type        = string
  description = "Subnet name to attach VMs to"
}

variable "public_key_path" {
  type        = string
  description = "Path to the local public SSH key"
}

variable "nodes" {
  type = map(object({
    role         = string
    machine_type = string
    disk_size_gb = number
  }))
  description = "Map of GCE nodes to create"
}
