# CT313: Mealie Recipe Manager
# Self-hosted recipe management with PostgreSQL backend
# Native deployment (Python/Node.js) with systemd management

resource "proxmox_virtual_environment_container" "mealie" {
  description = "Mealie - self-hosted recipe manager for multiple households"
  node_name   = "homelab"
  vm_id       = 314

  # Container initialization
  started = true

  # Unprivileged container (no special hardware needs)
  unprivileged = true

  initialization {
    hostname = "mealie"

    ip_config {
      ipv4 {
        address = "192.168.1.187/24"
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

  # Resource allocation
  cpu {
    cores = 2 # Sufficient for Python app + PostgreSQL
  }

  memory {
    dedicated = 2048 # 2GB RAM for Mealie + PostgreSQL
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 25 # 25GB for PostgreSQL, app, and recipe data
  }

  # Features
  features {
    nesting = true # Required for systemd
  }

  # Tags
  tags = ["web", "iac", "mealie"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}

output "mealie_container_id" {
  value = proxmox_virtual_environment_container.mealie.vm_id
}
