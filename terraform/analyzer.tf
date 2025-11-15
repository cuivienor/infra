# CT303: Analyzer Container
# Media analysis and remuxing - mkvtoolnix, mediainfo, organize scripts
# Privileged container for storage access consistency

resource "proxmox_virtual_environment_container" "analyzer" {
  description = "Analyzer container - Media analysis, remuxing, and organization"
  node_name   = "homelab"
  vm_id       = 303

  # Container initialization
  started = true
  
  # IMPORTANT: Privileged container for storage access consistency
  unprivileged = false

  initialization {
    hostname = "analyzer"
    
    ip_config {
      ipv4 {
        address = "192.168.1.133/24"
        gateway = "192.168.1.1"
      }
    }

    dns {
      domain  = " "
      servers = ["1.1.1.1", "8.8.8.8"]
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
    units = 1024  # Medium priority (same as ripper)
  }

  memory {
    dedicated = 4096  # 4GB RAM (analysis and remuxing operations)
    swap      = 2048  # 2GB swap
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 12  # 12GB for OS, tools, and temporary files
  }

  # Mount complete media directory from host (for analysis and organization)
  mount_point {
    volume = "/mnt/storage/media"
    path   = "/mnt/media"
    # Analyzer needs access to all media: staging, library, legacy-media, etc.
  }

  # Mount staging directory from host (media processing) - DEPRECATED, use /mnt/media/staging
  mount_point {
    volume = "/mnt/storage/media/staging"
    path   = "/mnt/staging"
    # Kept for backward compatibility with existing scripts
  }

  # Mount library directory from host (FileBot output) - DEPRECATED, use /mnt/media/library
  mount_point {
    volume = "/mnt/storage/media/library"
    path   = "/mnt/library"
    # Kept for backward compatibility with existing scripts
  }

  # Features
  features {
    nesting = true  # Enable nesting for potential nested operations
  }

  # Tags
  tags = ["media", "iac", "analyzer"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}

# Output the container's IP and ID
output "analyzer_container_id" {
  value       = proxmox_virtual_environment_container.analyzer.vm_id
  description = "Container ID (CTID)"
}

output "analyzer_container_ip" {
  value       = proxmox_virtual_environment_container.analyzer.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the analyzer container (static)"
}
