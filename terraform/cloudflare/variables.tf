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
# Using HTTP since this is internal traffic - Cloudflare handles external TLS
variable "caddy_address" {
  description = "Internal address of Caddy reverse proxy"
  type        = string
  default     = "http://192.168.1.111"
}

# Services to expose via tunnel
# Each service gets a CNAME record pointing to the tunnel
variable "tunnel_services" {
  description = "Map of services to expose via tunnel"
  type = map(object({
    hostname = string
  }))
  default = {
    wishlist = {
      hostname = "wishlist.paniland.com"
    }
    auth = {
      hostname = "auth.paniland.com"
    }
  }
}
