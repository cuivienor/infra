# SOPS-encrypted secrets for Proxmox homelab
# Edit with: sops secrets.sops.yaml

data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

locals {
  # Proxmox authentication
  proxmox_username = data.sops_file.secrets.data["proxmox_username"]
  proxmox_password = data.sops_file.secrets.data["proxmox_password"]
}
