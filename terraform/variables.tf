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
  description = "DNS servers for containers (will use local DNS when AdGuard is deployed)"
  type        = list(string)
  default     = ["1.1.1.1", "8.8.8.8"]
  # Future: ["192.168.1.110", "192.168.1.111", "1.1.1.1"] when AdGuard is deployed
}

variable "dns_domain" {
  description = "DNS search domain"
  type        = string
  default     = " " # Empty space to match Proxmox API behavior
}
