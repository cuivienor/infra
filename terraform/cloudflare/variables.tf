# Cloudflare module variables
# Note: Secrets (api_token, account_id, zone_id) are managed via SOPS - see secrets.sops.yaml

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
    wishlist = {
      hostname = "wishlist.paniland.com"
    }
    auth = {
      hostname = "auth.paniland.com"
    }
    mealie = {
      hostname = "mealie.paniland.com"
    }
    vault = {
      hostname = "vault.paniland.com"
    }
  }
}
