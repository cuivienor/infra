# CT301: Samba File Server
# Purpose: SMB file sharing for /mnt/storage access
# Optimized for large file streaming

resource "proxmox_virtual_environment_container" "samba" {
  description = "Samba file server for /mnt/storage - large file streaming optimized"
  node_name   = "homelab"
  vm_id       = 301

  # Container initialization
  started = true

  initialization {
    hostname = "samba"
    
    ip_config {
      ipv4 {
        address = "192.168.1.121/24"
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
    type            = "debian"
  }

  # Privileged container (required for mount points)
  unprivileged = false

  # Resource allocation
  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024  # 1GB RAM
    swap      = 512   # 512MB swap
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 8  # 8GB system disk
  }

  # Mount /mnt/storage from host (read-write for file sharing)
  mount_point {
    volume = "/mnt/storage"
    path   = "/mnt/storage"
    # Note: Mount options will be fine-tuned via LXC config if needed
  }

  # Features
  features {
    nesting = false  # Not needed for Samba
  }

  # Tags
  tags = ["infrastructure", "file-sharing", "samba", "iac"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}

# Output the container's IP for Ansible
output "samba_container_ip" {
  value       = proxmox_virtual_environment_container.samba.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the Samba container (static)"
}

output "samba_container_id" {
  value       = proxmox_virtual_environment_container.samba.vm_id
  description = "Container ID (CTID)"
}
