# CT302: Ripper Container
# MakeMKV Blu-ray/DVD ripper with optical drive passthrough
# Privileged container required for hardware device access

resource "proxmox_virtual_environment_container" "ripper" {
  description = "Ripper container - MakeMKV with optical drive passthrough"
  node_name   = "homelab"
  vm_id       = 302

  # Container initialization
  started = true
  
  # IMPORTANT: Privileged container required for device passthrough
  unprivileged = false

  initialization {
    hostname = "ripper"
    
    ip_config {
      ipv4 {
        address = "192.168.1.131/24"
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
  }

  memory {
    dedicated = 4096  # 4GB RAM (MakeMKV ripping operations)
    swap      = 2048  # 2GB swap
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 8  # 8GB for OS and MakeMKV binaries
  }

  # Mount only staging directory from host (least privilege)
  mount_point {
    volume = "/mnt/storage/media/staging"
    path   = "/mnt/staging"
    # Note: Device passthrough for optical drive must be configured via Ansible
    # Terraform BPG provider doesn't support LXC device passthrough configuration
  }

  # Features
  features {
    nesting = true  # Enable nesting for potential nested operations
  }

  # Tags
  tags = ["media", "iac", "ripper"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}

# Output the container's IP and ID
output "ripper_container_id" {
  value       = proxmox_virtual_environment_container.ripper.vm_id
  description = "Container ID (CTID)"
}

output "ripper_container_ip" {
  value       = proxmox_virtual_environment_container.ripper.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the ripper container (static)"
}
