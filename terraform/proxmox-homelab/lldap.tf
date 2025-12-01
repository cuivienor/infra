# CT308: LLDAP Container
# Purpose: Lightweight LDAP server for centralized user management
# Provides LDAP authentication backend for Authelia and other services

resource "proxmox_virtual_environment_container" "lldap" {
  description = "LLDAP - Lightweight LDAP server for user management"
  node_name   = "homelab"
  vm_id       = 308

  # Container initialization
  started = true

  initialization {
    hostname = "lldap"

    ip_config {
      ipv4 {
        address = "192.168.1.114/24"
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
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  # Unprivileged container (no hardware passthrough needed)
  unprivileged = true

  # Resource allocation - LLDAP is very lightweight (~10MB RAM)
  cpu {
    cores = 1
  }

  memory {
    dedicated = 256
    swap      = 128
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 4 # 4GB for OS and SQLite database
  }

  # Features
  features {
    nesting = true
  }

  # Tags
  tags = ["lldap", "infrastructure", "iac", "security"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
    ]
  }
}
