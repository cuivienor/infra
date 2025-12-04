# SOPS-encrypted secrets for Tailscale
# Edit with: sops secrets.sops.yaml

data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

locals {
  tailscale_oauth_client_id     = data.sops_file.secrets.data["tailscale_oauth_client_id"]
  tailscale_oauth_client_secret = data.sops_file.secrets.data["tailscale_oauth_client_secret"]
  tailscale_tailnet             = data.sops_file.secrets.data["tailscale_tailnet"]
}
