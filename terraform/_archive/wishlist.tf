# CT307: Wishlist Application
# Self-hosted gift registry and wishlist sharing
# Native Node.js deployment with systemd management

resource "proxmox_virtual_environment_container" "wishlist" {
  description = "Wishlist - self-hosted gift registry application"
  node_name   = "homelab"
  vm_id       = 307

  # Container initialization
  started = true

  # Unprivileged container (no special hardware needs)
  unprivileged = true

  initialization {
    hostname = "wishlist"

    ip_config {
      ipv4 {
        address = "192.168.1.186/24"
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
    cores = 2 # Sufficient for SvelteKit SSR + web scraping
  }

  memory {
    dedicated = 2048 # 2GB RAM for Node.js app + Prisma
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 20 # 20GB for Node.js, deps, SQLite DB, uploads
  }

  # Features
  features {
    nesting = false # Not needed for Node.js app
  }

  # Tags
  tags = ["web", "iac", "wishlist", "personal"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}
