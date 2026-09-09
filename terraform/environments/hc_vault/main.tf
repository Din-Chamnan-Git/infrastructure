# 1. Allocate a Static External IP for Vault Server
resource "google_compute_address" "vault_ip" {
  name   = "vault-server-static-ip"
  region = var.region
}

# 2. Firewall Rule allowing Vault API/UI (Port 8200) and Raft Cluster (Port 8201)
resource "google_compute_firewall" "allow_vault" {
  name    = "allow-vault-ingress"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "8200", "8201"]
  }

  target_tags   = ["vault-server"]
  source_ranges = ["0.0.0.0/0"]
}

# 3. Provision Dedicated GCP Compute Instance for HashiCorp Vault
resource "google_compute_instance" "vault" {
  name         = "vault-server-dev"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["vault-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.vault_ip.address
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}

# 4. Cloudflare DNS Record pointing to Vault Server Static IP
resource "cloudflare_record" "vault_dns" {
  zone_id = var.cloudflare_zone_id
  name    = var.vault_subdomain
  content = google_compute_address.vault_ip.address
  type    = "A"
  proxied = false # Direct connection for Vault API / Port 8200 access
  ttl     = 1
}
