# SOPS-encrypted secrets for Cloudflare
# Edit with: sops secrets.sops.yaml

data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

locals {
  cloudflare_api_token  = data.sops_file.secrets.data["cloudflare_api_token"]
  cloudflare_account_id = data.sops_file.secrets.data["cloudflare_account_id"]
  cloudflare_zone_id    = data.sops_file.secrets.data["cloudflare_zone_id"]
  resend_dkim_value     = data.sops_file.secrets.data["resend_dkim_value"]
}
