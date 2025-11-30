# CT312: Authelia SSO Container
# Purpose: Centralized Single Sign-On authentication with TOTP 2FA
# Protects homelab services via Caddy forward_auth integration

resource "proxmox_virtual_environment_container" "authelia" {
  description = "Authelia SSO - centralized authentication for homelab services"
  node_name   = "homelab"
  vm_id       = 312

  # Container initialization
  started = true

  initialization {
    hostname = "authelia"

    ip_config {
      ipv4 {
        address = "192.168.1.112/24"
        gateway = "192.168.1.1"
      }
    }

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    user_account {
      # SSH keys automatically loaded from ansible/files/ssh-keys/
      keys = local.ssh_public_keys
    }
  }

  # Network configuration
  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  # Operating system
  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  # Unprivileged container (no hardware passthrough needed)
  unprivileged = true

  # Resource allocation - lightweight authentication service
  cpu {
    cores = 1
  }

  memory {
    dedicated = 512 # 512MB RAM (actual usage ~30-50MB)
    swap      = 256
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 8 # 8GB for OS and SQLite database
  }

  # Features
  features {
    nesting = true
  }

  # Tags
  tags = ["authelia", "infrastructure", "iac", "security"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
    ]
  }
}
