resource "google_compute_instance" "node" {
  for_each     = var.nodes
  name         = "${each.key}-dev"
  machine_type = each.value.machine_type
  zone         = var.zone

  # These tags must match the target_tags in your firewall rules!
  tags = ["k8s-node", each.value.role]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = each.value.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnet_name
    access_config {} # Creates an ephemeral public IP for the VM
  }

  metadata = {
    # Inject your SSH key, creating the user 'ubuntu'
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  # Required for Kubernetes routing between pods
  can_ip_forward = true
}
