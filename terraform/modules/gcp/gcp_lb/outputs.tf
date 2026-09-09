output "lb_public_ip" {
  value       = google_compute_address.lb_ip.address
  description = "The public static IP address of the GCP Load Balancer"
}
