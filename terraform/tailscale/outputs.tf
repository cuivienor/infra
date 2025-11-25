# Tailscale outputs

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
