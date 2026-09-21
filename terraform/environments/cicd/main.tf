# 1. Allocate a Static External IP for CI/CD Server
resource "google_compute_address" "cicd_ip" {
  name   = "cicd-server-static-ip"
  region = var.region
}

# 2. Firewall Rule allowing SSH, HTTP, HTTPS, Jenkins, SonarQube & Nexus
resource "google_compute_firewall" "allow_cicd" {
  name    = "allow-cicd-ingress"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8080", "50000", "9000", "8081", "8082"]
  }

  target_tags   = ["cicd-server"]
  source_ranges = ["0.0.0.0/0"]
}

# 3. Provision Dedicated GCP Compute Instance for CI/CD Platform
resource "google_compute_instance" "cicd" {
  name         = "cicd-server-dev"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["cicd-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.cicd_ip.address
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}

# 4. Cloudflare DNS Records for CI/CD Subdomains
resource "cloudflare_record" "jenkins_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "jenkins"
  content = google_compute_address.cicd_ip.address
  type    = "A"
  proxied = false
  ttl     = 1
}

resource "cloudflare_record" "sonar_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "sonar"
  content = google_compute_address.cicd_ip.address
  type    = "A"
  proxied = false
  ttl     = 1
}

resource "cloudflare_record" "nexus_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "nexus"
  content = google_compute_address.cicd_ip.address
  type    = "A"
  proxied = false
  ttl     = 1
}

resource "cloudflare_record" "registry_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "registry"
  content = google_compute_address.cicd_ip.address
  type    = "A"
  proxied = false
  ttl     = 1
}
