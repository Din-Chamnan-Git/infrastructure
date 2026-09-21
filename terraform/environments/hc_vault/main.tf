# 1. Reference the existing K8s VPC and subnet (created by gcp_dev Terraform).
# Vault is placed in the SAME network as Kubernetes so all nodes can
# communicate with each other via private IP without extra firewall complexity.
data "google_compute_network" "k8s_vpc" {
  name = "gcp-k8s-vpc"
}

data "google_compute_subnetwork" "k8s_subnet" {
  name   = "gcp-k8s-subnet"
  region = var.region
}

# 2. Allocate a Static External IP for Vault Server
resource "google_compute_address" "vault_ip" {
  name   = "vault-server-static-ip"
  region = var.region
}

# 3. Firewall Rule — allow Vault API (8200), Raft (8201), SSH (22) from internet
resource "google_compute_firewall" "allow_vault" {
  name    = "allow-vault-ingress"
  network = data.google_compute_network.k8s_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8200", "8201"]
  }

  target_tags   = ["vault-server"]
  source_ranges = ["0.0.0.0/0"]
}

# 4. Provision Vault VM inside the same VPC as Kubernetes
# Private IP will be auto-assigned from the 10.10.1.0/24 subnet.
# This allows direct private communication with K8s nodes (master + workers).
resource "google_compute_instance" "vault" {
  name         = "vault-server-dev"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["vault-server", "k8s-node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = data.google_compute_network.k8s_vpc.name
    subnetwork = data.google_compute_subnetwork.k8s_subnet.name
    access_config {
      nat_ip = google_compute_address.vault_ip.address
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}

# 5. Cloudflare DNS Record pointing to Vault Server Static IP
resource "cloudflare_record" "vault_dns" {
  zone_id = var.cloudflare_zone_id
  name    = var.vault_subdomain
  content = google_compute_address.vault_ip.address
  type    = "A"
  proxied = false # Direct connection for Vault API / Port 8200 access
  ttl     = 1
}

# Output Vault's private IP so Ansible and Kubernetes can reference it
output "vault_private_ip" {
  value       = google_compute_instance.vault.network_interface[0].network_ip
  description = "Vault VM private IP within gcp-k8s-vpc subnet"
}
