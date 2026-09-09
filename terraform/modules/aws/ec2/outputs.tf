output "nodes" {
  description = "Map of created EC2 node instances containing IP details"
  value = {
    for k, v in aws_instance.node : k => {
      id         = v.id
      public_ip  = v.public_ip
      private_ip = v.private_ip
      role       = v.tags["Role"]
    }
  }
}
