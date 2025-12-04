# Terraform variables for Proxmox homelab containers
# Note: Secrets (username/password) are managed via SOPS - see secrets.sops.yaml

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.1.100:8006"
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (for self-signed certs)"
  type        = bool
  default     = true
}

# Network configuration
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
