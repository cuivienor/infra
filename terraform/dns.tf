# CT310: DNS Backup Container
# Purpose: Backup DNS server with AdGuard Home for failover
# Primary DNS runs on Pi4 (192.168.1.102), this is the backup

resource "proxmox_virtual_environment_container" "dns" {
  description = "DNS backup - AdGuard Home for failover (primary on Pi4)"
  node_name   = "homelab"
  vm_id       = 310

  # Container initialization
  started = true

  initialization {
    hostname = "dns"

    ip_config {
      ipv4 {
        address = "192.168.1.110/24"
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

  # Privileged container (for consistency with other containers)
  unprivileged = false

  # Resource allocation - lightweight DNS service
  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024 # 1GB RAM (matches samba, lightest container)
    swap      = 512
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 8 # 8GB for OS and AdGuard Home
  }

  # Features
  features {
    nesting = true # May be needed for some operations
  }

  # Tags
  tags = ["dns", "infrastructure", "iac"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}
