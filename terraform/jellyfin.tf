# CT305: Jellyfin Media Server
# High-priority media streaming server with dual GPU support
# Privileged container for simplified GPU passthrough

resource "proxmox_virtual_environment_container" "jellyfin" {
  description = "Jellyfin media server - dual GPU hardware transcoding (Intel Arc primary, NVIDIA ready)"
  node_name   = "homelab"
  vm_id       = 305

  # Container initialization
  started = true

  # IMPORTANT: Privileged container for GPU passthrough
  unprivileged = false

  initialization {
    hostname = "jellyfin"

    ip_config {
      ipv4 {
        address = "192.168.1.130/24"
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

  # Resource allocation - HIGHEST PRIORITY
  # Jellyfin is the primary user-facing service
  cpu {
    cores = 4 # Match transcoder, highest among all containers
  }

  memory {
    dedicated = 8192 # 8GB RAM for multiple streams + transcoding + metadata
    swap      = 4096 # 4GB swap for burst capacity
  }

  # Disk configuration
  # Old CT101 was 100% full at 8GB - need space for metadata, cache, thumbnails
  disk {
    datastore_id = "local-lvm"
    size         = 32 # 32GB for Jellyfin data, metadata cache, transcoding cache
  }

  # Mount media directory from host (standardized path)
  mount_point {
    volume = "/mnt/storage/media"
    path   = "/mnt/media"
    # Provides access to library/movies, library/tv, and staging directories
    # Jellyfin libraries should point to /mnt/media/library/movies and /mnt/media/library/tv
    # Note: Consider read-only after testing: add ro option via LXC config
  }

  # Features
  features {
    nesting = true # May be needed for certain Jellyfin features
  }

  # Tags
  tags = ["media", "iac", "jellyfin", "high-priority"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}
