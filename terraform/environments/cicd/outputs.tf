output "cicd_public_ip" {
  description = "Public IP address of the dedicated CI/CD server"
  value       = google_compute_address.cicd_ip.address
}

output "jenkins_url" {
  description = "Jenkins HTTPS Dashboard URL"
  value       = "https://${cloudflare_record.jenkins_dns.hostname}"
}

output "sonarqube_url" {
  description = "SonarQube HTTPS Dashboard URL"
  value       = "https://${cloudflare_record.sonar_dns.hostname}"
}

output "nexus_url" {
  description = "Nexus Repository Manager HTTPS Dashboard URL"
  value       = "https://${cloudflare_record.nexus_dns.hostname}"
}

output "registry_url" {
  description = "Nexus Private Docker Registry HTTPS URL"
  value       = "https://${cloudflare_record.registry_dns.hostname}"
}
