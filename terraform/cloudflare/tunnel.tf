# Cloudflare Tunnel configuration
#
# Creates a tunnel for secure public access to homelab services.
# All traffic routes through Caddy reverse proxy for centralized auth.

# Generate random tunnel secret
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# Create the tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = local.cloudflare_account_id
  name       = var.tunnel_name
  secret     = random_id.tunnel_secret.b64_std
}

# Configure tunnel ingress rules
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = local.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config {
    # Route each service through Caddy
    dynamic "ingress_rule" {
      for_each = var.tunnel_services
      content {
        hostname = ingress_rule.value.hostname
        service  = var.caddy_address
        origin_request {
          no_tls_verify      = true                        # Skip cert validation (internal)
          origin_server_name = ingress_rule.value.hostname # SNI for TLS handshake
        }
      }
    }

    # Catch-all rule (required by Cloudflare)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# Create DNS CNAME records for each service
resource "cloudflare_record" "tunnel_services" {
  for_each = var.tunnel_services

  zone_id = local.cloudflare_zone_id
  name    = split(".", each.value.hostname)[0] # Extract subdomain (e.g., "wishlist")
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true # Enable Cloudflare proxy (DDoS protection, caching)
  ttl     = 1    # Auto TTL when proxied

  comment = "Cloudflare Tunnel - managed by Terraform"
}
