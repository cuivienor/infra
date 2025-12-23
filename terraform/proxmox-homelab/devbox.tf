# CT320: NixOS Dev Container
# NixOS development environment for learning Nix and managing configurations
# Uses official NixOS LXC template from Hydra

resource "proxmox_virtual_environment_container" "devbox" {
  description = "NixOS dev environment - flake-based config management"
  node_name   = "homelab"
  vm_id       = 320

  # Container initialization
  started = true

  # Privileged required for Nix to work properly in LXC
  unprivileged = false

  initialization {
    hostname = "devbox"

    ip_config {
      ipv4 {
        address = "192.168.1.140/24"
        gateway = "192.168.1.1"
      }
    }

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    user_account {
      keys = local.ssh_public_keys
    }
  }

  # Network configuration
  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  # Operating system - NixOS requires unmanaged type
  operating_system {
    template_file_id = "local:vztmpl/nixos-24.11-proxmox.tar.xz"
    type             = "unmanaged"
  }

  # Resource allocation
  cpu {
    cores = 4
  }

  memory {
    dedicated = 8192 # 8GB - Nix builds are memory-hungry
    swap      = 4096 # 4GB swap
  }

  # Disk configuration - Nix store grows fast
  disk {
    datastore_id = "local-lvm"
    size         = 50 # 50GB for Nix store and generations
  }

  # Console mode instead of tty (fixes NixOS getty issues)
  console {
    type = "console"
  }

  # Features - nesting required for Nix sandbox/builds
  features {
    nesting = true
  }

  # Tags
  tags = ["dev", "iac", "nixos"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
    ]
  }
}
