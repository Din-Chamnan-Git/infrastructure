# Allow SSH and Kubernetes API server access from internet / laptop
resource "google_compute_firewall" "allow_ssh" { 
    name    = "k8s-allow-ssh"
    network = var.network_name

    allow {
        protocol = "tcp"
        ports    = ["22", "6443"]
    }

    source_ranges = ["0.0.0.0/0"]
    target_tags   = ["k8s-node"]
}

# Allow all traffic between instances within the internal subnet CIDR 
resource "google_compute_firewall" "allow_internal" {
    name    = "k8s-allow-internal"
    network = var.network_name

    allow {
        protocol = "icmp"
    }

    allow {
        protocol = "tcp"
        ports    = ["0-65535"]
    }
    allow {
        protocol = "udp"
        ports    = ["0-65535"]
    }
    source_ranges = [var.ip_cidr_range]
}