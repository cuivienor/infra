# Centralized outputs for homelab Terraform infrastructure
# Following TFLint standard module structure best practice

# --------------------------------------------------
# Container IDs and IPs
# --------------------------------------------------

output "analyzer_container_id" {
  value       = proxmox_virtual_environment_container.analyzer.vm_id
  description = "Container ID (CTID) for the analyzer container"
}

output "analyzer_container_ip" {
  value       = proxmox_virtual_environment_container.analyzer.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the analyzer container (static)"
}

output "backup_container_id" {
  value       = proxmox_virtual_environment_container.backup.vm_id
  description = "Container ID (CTID) for the backup container"
}

output "backup_container_ip" {
  value       = proxmox_virtual_environment_container.backup.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the backup container (static)"
}

output "dns_container_id" {
  value       = proxmox_virtual_environment_container.dns.vm_id
  description = "Container ID (CTID) for the DNS container"
}

output "dns_container_ip" {
  value       = proxmox_virtual_environment_container.dns.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the DNS container (static)"
}

output "jellyfin_container_id" {
  value       = proxmox_virtual_environment_container.jellyfin.vm_id
  description = "Container ID (CTID) for the Jellyfin container"
}

output "jellyfin_container_ip" {
  value       = proxmox_virtual_environment_container.jellyfin.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the Jellyfin container (static)"
}

output "proxy_container_id" {
  value       = proxmox_virtual_environment_container.proxy.vm_id
  description = "Container ID (CTID) for the proxy container"
}

output "proxy_container_ip" {
  value       = proxmox_virtual_environment_container.proxy.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the proxy container (static)"
}

output "ripper_container_id" {
  value       = proxmox_virtual_environment_container.ripper.vm_id
  description = "Container ID (CTID) for the ripper container"
}

output "ripper_container_ip" {
  value       = proxmox_virtual_environment_container.ripper.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the ripper container (static)"
}

output "samba_container_id" {
  value       = proxmox_virtual_environment_container.samba.vm_id
  description = "Container ID (CTID) for the Samba container"
}

output "samba_container_ip" {
  value       = proxmox_virtual_environment_container.samba.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the Samba container (static)"
}

output "transcoder_container_id" {
  value       = proxmox_virtual_environment_container.transcoder.vm_id
  description = "Container ID (CTID) for the transcoder container"
}

output "transcoder_container_ip" {
  value       = proxmox_virtual_environment_container.transcoder.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the transcoder container (static)"
}

# --------------------------------------------------
# SSH Keys
# --------------------------------------------------

output "ssh_keys_loaded" {
  value       = length(local.ssh_public_keys)
  description = "Number of SSH public keys loaded from ansible/files/ssh-keys/"
}

output "ssh_key_files" {
  value       = local.ssh_key_files
  description = "SSH key files found"
}

# --------------------------------------------------
# Tailscale Auth Keys
# --------------------------------------------------

output "tailscale_pi4_auth_key" {
  value       = tailscale_tailnet_key.pi4_router.key
  sensitive   = true
  description = "Auth key for Pi4 subnet router"
}

output "tailscale_proxmox_auth_key" {
  value       = tailscale_tailnet_key.proxmox_router.key
  sensitive   = true
  description = "Auth key for Proxmox subnet router"
}
