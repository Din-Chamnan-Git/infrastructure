output "master_sg_id" {
  description = "The Security Group ID for K8s Master Control Plane nodes"
  value       = aws_security_group.master_sg.id
}

output "worker_sg_id" {
  description = "The Security Group ID for K8s Worker nodes"
  value       = aws_security_group.worker_sg.id
}
