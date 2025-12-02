# Cloudflare module variables

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone:DNS:Edit, Account:Cloudflare Tunnel:Edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for paniland.com"
  type        = string
}

variable "tunnel_name" {
  description = "Name for the Cloudflare Tunnel"
  type        = string
  default     = "homelab-tunnel"
}

# Caddy reverse proxy address (internal)
variable "caddy_address" {
  description = "Internal address of Caddy reverse proxy"
  type        = string
  default     = "https://192.168.1.111"
}

# Services to expose via tunnel
# Each service gets a CNAME record pointing to the tunnel
variable "tunnel_services" {
  description = "Map of services to expose via tunnel"
  type = map(object({
    hostname = string
  }))
  default = {
    jellyfin = {
      hostname = "jellyfin.paniland.com"
    }
    wishlist = {
      hostname = "wishlist.paniland.com"
    }
    auth = {
      hostname = "auth.paniland.com"
    }
  }
}

# Resend DKIM public key for email authentication
variable "resend_dkim_value" {
  description = "DKIM public key value from Resend dashboard"
  type        = string
}
