output "vpc_id" {
  description = "VPC ID of the dev cluster"
  value       = module.vpc.vpc_id
}

output "subnet_id" {
  description = "Public Subnet ID of the dev cluster"
  value       = module.vpc.subnet_id
}

output "master_nodes" {
  description = "Master node instance IPs"
  value       = module.master_nodes.nodes
}

# output "worker_nodes" {
#   description = "Worker node instance IPs"
#   value       = module.worker_nodes.nodes
# }
