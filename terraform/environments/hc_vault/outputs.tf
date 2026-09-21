output "vault_public_ip" {
  description = "Public IP address of the dedicated Vault server"
  value       = google_compute_address.vault_ip.address
}

output "vault_hostname" {
  description = "Full DNS hostname of the Vault server"
  value       = cloudflare_record.vault_dns.hostname
}

output "vault_ui_url" {
  description = "Web UI URL for HashiCorp Vault"
  value       = "https://${cloudflare_record.vault_dns.hostname}:8200"
}
