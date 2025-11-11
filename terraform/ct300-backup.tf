# CT300: Backup Container
# Restic-based backups of /mnt/storage data to Backblaze B2
# Includes Backrest web UI for monitoring and restore operations

resource "proxmox_virtual_environment_container" "backup" {
  description = "Backup container - restic + Backrest UI for /mnt/storage data"
  node_name   = "homelab"
  vm_id       = 300

  # Container initialization
  started = true

  initialization {
    hostname = "backup"
    
    ip_config {
      ipv4 {
        address = "192.168.1.58/24"
        gateway = "192.168.1.1"
      }
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

  # Resource allocation
  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048  # 2GB RAM (Backrest + restic operations)
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 20  # 20GB for Backrest data, restic cache, logs
  }

  # Mount /mnt/storage from host (read-only for safety)
  mount_point {
    volume = "/mnt/storage"
    path   = "/mnt/storage"
    # Note: mount options and read-only flag will be configured via Ansible/LXC config
  }

  # Features
  features {
    nesting = false  # Not needed for backup operations
  }

  # Tags
  tags = ["backup", "iac", "restic"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}

# Output the container's IP for Ansible
output "backup_container_ip" {
  value       = proxmox_virtual_environment_container.backup.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the backup container (static)"
}

output "backup_container_id" {
  value       = proxmox_virtual_environment_container.backup.vm_id
  description = "Container ID (CTID)"
}
