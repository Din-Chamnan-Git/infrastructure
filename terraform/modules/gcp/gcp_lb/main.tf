# 1. Reserve a static external public IP address
resource "google_compute_address" "lb_ip" {
  name   = "k8s-lb-ip"
  region = var.region
}

# 2. Define a Health Check (Checks /ping on Traefik Ingress port 80)
resource "google_compute_http_health_check" "hc" {
  name                = "k8s-ingress-healthcheck"
  request_path        = "/ping"
  port                = 80
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3
}

# 3. Create Target Pool for Worker Nodes
resource "google_compute_target_pool" "pool" {
  name      = "k8s-worker-pool"
  region    = var.region
  instances = var.worker_self_links

  health_checks = [
    google_compute_http_health_check.hc.name
  ]
}

# 4. Forwarding Rule for HTTP (Port 80)
resource "google_compute_forwarding_rule" "http" {
  name        = "k8s-forward-http"
  region      = var.region
  ip_address  = google_compute_address.lb_ip.address
  ip_protocol = "TCP"
  port_range  = "80"
  target      = google_compute_target_pool.pool.self_link
}

# 5. Forwarding Rule for HTTPS (Port 443)
resource "google_compute_forwarding_rule" "https" {
  name        = "k8s-forward-https"
  region      = var.region
  ip_address  = google_compute_address.lb_ip.address
  ip_protocol = "TCP"
  port_range  = "443"
  target      = google_compute_target_pool.pool.self_link
}

# 6. Firewall rule to allow external traffic to the worker nodes
resource "google_compute_firewall" "allow_lb" {
  name    = "k8s-allow-lb-traffic"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "10254"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["worker"]
}
