# Cloudflare module outputs

output "tunnel_id" {
  description = "Cloudflare Tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

output "tunnel_name" {
  description = "Cloudflare Tunnel name"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.name
}

# Token used by cloudflared daemon to authenticate
# Format: <tunnel_id>:<account_tag>:<tunnel_secret>
output "tunnel_token" {
  description = "Tunnel token for cloudflared daemon (sensitive)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.tunnel_token
  sensitive   = true
}

output "tunnel_cname" {
  description = "CNAME target for tunnel DNS records"
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
}

output "exposed_services" {
  description = "Services exposed via tunnel"
  value       = [for svc in var.tunnel_services : svc.hostname]
}
