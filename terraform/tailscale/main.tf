# Main Terraform configuration for Tailscale infrastructure

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.16"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1"
    }
  }
}

provider "tailscale" {
  oauth_client_id     = local.tailscale_oauth_client_id
  oauth_client_secret = local.tailscale_oauth_client_secret
  tailnet             = local.tailscale_tailnet
}
