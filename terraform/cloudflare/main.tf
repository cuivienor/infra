# Cloudflare Terraform configuration
#
# Manages Cloudflare Tunnel for secure public access to homelab services.
# Traffic flow: Internet → Cloudflare Edge → Tunnel → Caddy → Services
#
# Usage:
#   cd terraform/cloudflare
#   terraform init
#   terraform plan
#   terraform apply

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
