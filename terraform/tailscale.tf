# Tailscale Infrastructure Configuration
# Manages ACLs, DNS, and auth keys for remote access

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
  tailnet             = var.tailscale_tailnet
}

# Access Control List - defines who can access what
resource "tailscale_acl" "homelab" {
  acl = jsonencode({
    // Tag ownership - who can assign these tags
    tagOwners = {
      "tag:server"        = ["autogroup:admin"]
      "tag:subnet-router" = ["autogroup:admin"]
    }

    // Group definitions for access control
    groups = {
      // Add friend emails here when you want to share
      "group:friends" = []
    }

    // Access rules
    acls = [
      // Admins (you) can access everything
      {
        action = "accept"
        src    = ["autogroup:admin"]
        dst    = ["*:*"]
      },
      // Friends can access web services only
      {
        action = "accept"
        src    = ["group:friends"]
        dst = [
          "192.168.1.111:80,443", // Proxy (HTTPS services)
          "192.168.1.130:8096",   // Jellyfin direct (if needed)
        ]
      }
    ]

    // Node attributes (Mullvad exit nodes for active devices)
    nodeAttrs = [
      { target = ["100.102.24.110"], attr = ["mullvad"] }, // google-pixel-9a (phone)
      { target = ["100.122.226.116"], attr = ["mullvad"] } // surface (laptop)
    ]

    // Auto-approve subnet routes and exit nodes from tagged devices
    autoApprovers = {
      routes = {
        "192.168.1.0/24" = ["tag:subnet-router"]
      }
      exitNode = ["tag:subnet-router"]
    }
  })
}

# DNS Configuration - route queries to Pi4 AdGuard
resource "tailscale_dns_nameservers" "homelab" {
  nameservers = [
    "192.168.1.102" // Pi4 AdGuard Home
  ]
}

resource "tailscale_dns_preferences" "homelab" {
  magic_dns = true
}

# Split DNS - route specific domains to your DNS
resource "tailscale_dns_split_nameservers" "paniland" {
  domain      = "paniland.com"
  nameservers = ["192.168.1.102"] // Pi4
}

resource "tailscale_dns_split_nameservers" "home_arpa" {
  domain      = "home.arpa"
  nameservers = ["192.168.1.102"] // Pi4
}

# Auth key for Pi4 subnet router (primary)
resource "tailscale_tailnet_key" "pi4_router" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 7776000 // 90 days (maximum)
  description   = "Pi4 primary subnet router"
  tags          = ["tag:subnet-router"]
}

# Auth key for Proxmox subnet router (secondary)
resource "tailscale_tailnet_key" "proxmox_router" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 7776000 // 90 days (maximum)
  description   = "Proxmox secondary subnet router"
  tags          = ["tag:subnet-router"]
}

# Outputs - for use in Ansible
output "tailscale_pi4_auth_key" {
  value       = tailscale_tailnet_key.pi4_router.key
  sensitive   = true
  description = "Auth key for Pi4 subnet router"
}

output "tailscale_proxmox_auth_key" {
  value       = tailscale_tailnet_key.proxmox_router.key
  sensitive   = true
  description = "Auth key for Proxmox subnet router"
}
