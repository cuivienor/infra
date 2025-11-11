# Terraform variables for homelab infrastructure

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
  default     = "https://192.168.1.56:8006"
}

variable "proxmox_username" {
  description = "Proxmox API username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
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
