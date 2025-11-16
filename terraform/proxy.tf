# Reverse Proxy Container
# Purpose: Caddy reverse proxy with automatic HTTPS via Let's Encrypt DNS-01 challenge
# Proxies traffic to internal services (Jellyfin, Backrest, etc.)

resource "proxmox_virtual_environment_container" "proxy" {
  description = "Caddy reverse proxy - automatic HTTPS via Let's Encrypt DNS-01"
  node_name   = "homelab"
  vm_id       = 311

  # Container initialization
  started = true

  initialization {
    hostname = "proxy"

    ip_config {
      ipv4 {
        # IMPORTANT: If changing this IP, also update Cloudflare API token IP restriction
        # Token is restricted to this IP for security (Zone:DNS:Edit for paniland.com)
        address = "192.168.1.111/24"
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

  # Privileged container (needed for binding to ports 80/443)
  unprivileged = false

  # Resource allocation - lightweight proxy service
  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024 # 1GB RAM
    swap      = 512
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 8 # 8GB for OS and Caddy + certificates
  }

  # Features
  features {
    nesting = false # Not needed for Caddy
  }

  # Tags
  tags = ["proxy", "infrastructure", "iac"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}

# Output the container's IP and ID
output "proxy_container_id" {
  value       = proxmox_virtual_environment_container.proxy.vm_id
  description = "Container ID (CTID)"
}

output "proxy_container_ip" {
  value       = proxmox_virtual_environment_container.proxy.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of the proxy container (static)"
}
