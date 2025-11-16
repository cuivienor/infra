# Terraform variables for homelab infrastructure

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.1.100:8006"
}

variable "proxmox_username" {
  description = "Proxmox API username (not used if api_token is set)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox API password (not used if api_token is set)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_api_token" {
  description = "Proxmox API token (format: user@realm!tokenid=secret)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (for self-signed certs)"
  type        = bool
  default     = true
}

# SSH public key for container access
variable "ssh_public_key" {
  description = "SSH public key for root access to containers"
  type        = string
  default     = ""
}

# Network configuration
variable "gateway" {
  description = "Default gateway for containers"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_servers" {
  description = "DNS servers for containers (local AdGuard with external fallback)"
  type        = list(string)
  default     = ["192.168.1.102", "192.168.1.110", "1.1.1.1"]
  # Pi4 AdGuard (primary), CT310 AdGuard (backup), Cloudflare (external fallback)
}

variable "dns_domain" {
  description = "DNS search domain"
  type        = string
  default     = "" # Empty string - no search domain configured
}

# Tailscale configuration
variable "tailscale_oauth_client_id" {
  description = "Tailscale OAuth client ID"
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "Tailscale OAuth client secret"
  type        = string
  sensitive   = true
}

variable "tailscale_tailnet" {
  description = "Tailscale tailnet ID (e.g., Ty559Ri2ZY91CNTRL)"
  type        = string
}
