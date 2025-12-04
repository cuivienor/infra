# SOPS-encrypted secrets for LLDAP
# Edit with: sops secrets.sops.yaml

data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

locals {
  lldap_admin_password      = data.sops_file.secrets.data["lldap_admin_password"]
  initial_user_password     = data.sops_file.secrets.data["initial_user_password"]
  service_account_passwords = yamldecode(data.sops_file.secrets.data["service_account_passwords"])
}
