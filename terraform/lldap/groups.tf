# LLDAP Groups
# Dynamically created from terraform/users.yaml

locals {
  users_config = yamldecode(file("${path.module}/../users.yaml"))
}

# Create all groups from users.yaml (except service_accounts which is a meta-group)
resource "lldap_group" "groups" {
  for_each = {
    for name, config in local.users_config.groups : name => config
    if name != "service_accounts"
  }

  display_name = each.key
}

# Reference built-in LLDAP groups (these exist automatically)
# lldap_admin (id=1) - Full admin rights
# lldap_password_manager (id=2) - Can change user passwords
# lldap_strict_readonly (id=3) - Read-only access
