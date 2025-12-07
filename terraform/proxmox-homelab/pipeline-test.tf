# CT199: Pipeline Test Container
# E2E testing for media-pipeline project with mock-makemkv
# Privileged container for storage access consistency

resource "proxmox_virtual_environment_container" "pipeline_test" {
  description = "Pipeline test container - E2E testing with mock-makemkv"
  node_name   = "homelab"
  vm_id       = 199

  # Container initialization
  started = true

  # IMPORTANT: Privileged container for storage access consistency
  unprivileged = false

  initialization {
    hostname = "pipeline-test"

    ip_config {
      ipv4 {
        address = "192.168.1.199/24"
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
    cores = 2
    units = 1024 # Medium priority
  }

  memory {
    dedicated = 2048 # 2GB RAM (testing doesn't need much)
    swap      = 1024 # 1GB swap
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 16 # 16GB for OS, tools, and synthetic MKV files
  }

  # Mount production media directory as READ-ONLY (for TUI testing)
  mount_point {
    volume    = "/mnt/storage/media"
    path      = "/mnt/media"
    read_only = true
    # Production data mounted read-only for TUI testing against real state
    # Use MEDIA_BASE=/mnt/media to test TUI against production
  }

  # Features
  features {
    nesting = true # Enable nesting for potential nested operations
  }

  # Tags
  tags = ["test", "media", "iac"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}
