# CT321: Vault Container
# Purpose: CouchDB backend for Obsidian LiveSync family knowledge vault
# Stores encrypted notes synced across devices via LiveSync Bridge/plugin

resource "proxmox_virtual_environment_container" "vault" {
  description = "Vault - CouchDB for Obsidian LiveSync family notes"
  node_name   = "homelab"
  vm_id       = 321

  # Container initialization
  started = true

  initialization {
    hostname = "vault"

    ip_config {
      ipv4 {
        address = "192.168.1.150/24"
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

  # Resource allocation - CouchDB needs more than LLDAP but still lightweight
  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024
    swap      = 256
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 8 # 8GB for OS and CouchDB data
  }

  # Features
  features {
    nesting = true
  }

  # Tags
  tags = ["vault", "infrastructure", "iac", "database"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
    ]
  }
}
