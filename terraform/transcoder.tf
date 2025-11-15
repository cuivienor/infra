# CT304: Transcoder Container
# FFmpeg transcoding with Intel Arc A380 GPU passthrough
# Privileged container required for GPU hardware access

resource "proxmox_virtual_environment_container" "transcoder" {
  description = "Transcoder - FFmpeg with Intel Arc GPU passthrough"
  node_name   = "homelab"
  vm_id       = 304

  # Container initialization
  started = true
  
  # IMPORTANT: Privileged container required for GPU device passthrough
  unprivileged = false

  initialization {
    hostname = "transcoder"
    
    ip_config {
      ipv4 {
        address = "192.168.1.132/24"  # Keep existing IP from CT201
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
  # Transcoding is CPU/GPU intensive
  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192  # 8GB RAM for FFmpeg operations
    swap      = 2048  # 2GB swap
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 20  # 20GB for OS, FFmpeg, and temp files
  }

  # Mount staging directory from host (least privilege approach)
  # Transcoder only needs access to remuxed -> transcoded pipeline
  mount_point {
    volume = "/mnt/storage/media/staging"
    path   = "/mnt/staging"
    # Note: GPU passthrough must be configured via Ansible
    # Terraform BPG provider doesn't support LXC device passthrough configuration
  }

  # Features
  features {
    nesting = true  # Enable nesting for potential nested operations
  }

  # Tags
  tags = ["media", "iac", "transcoder", "gpu"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}

# Output the container's IP and ID
output "transcoder_container_id" {
  value       = proxmox_virtual_environment_container.transcoder.vm_id
  description = "Container ID (CTID)"
}

output "transcoder_container_ip" {
  value       = proxmox_virtual_environment_container.transcoder.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the transcoder container (static)"
}
