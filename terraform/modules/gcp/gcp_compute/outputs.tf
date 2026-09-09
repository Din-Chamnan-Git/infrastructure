output "node_ips" {
  value = {
    for k, v in google_compute_instance.node : k => {
      public_ip  = v.network_interface[0].access_config[0].nat_ip
      private_ip = v.network_interface[0].network_ip
    }
  }
}

output "worker_self_links" {
  value = [
    for k, v in google_compute_instance.node : v.self_link if contains(v.tags, "worker")
  ]
  description = "The self_links of the worker nodes to target in the load balancer"
}
