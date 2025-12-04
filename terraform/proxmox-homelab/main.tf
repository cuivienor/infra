# Main Terraform configuration for Proxmox homelab containers

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1"
    }
  }
}

# Proxmox provider configuration
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure

  # Authentication via SOPS-encrypted secrets
  username = local.proxmox_username
  password = local.proxmox_password

  ssh {
    agent    = true
    username = "root"
  }
}
