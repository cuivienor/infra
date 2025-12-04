# LLDAP Users
# Dynamically created from terraform/users.yaml
#
# IMPORTANT: Human user passwords are managed with lifecycle { ignore_changes = [password] }
# This means:
# - Initial creation uses local.initial_user_password (from SOPS)
# - After user changes password via Authelia, Terraform won't overwrite it
# - To force a password reset, use taint or remove from state

# Human users (password changes ignored after creation)
resource "lldap_user" "users" {
  for_each = {
    for username, user in local.users_config.users : username => user
    if !lookup(user, "is_service_account", false)
  }

  username     = each.key
  email        = each.value.email
  display_name = each.value.display_name
  password     = local.initial_user_password

  lifecycle {
    ignore_changes = [password]
  }
}

# Service accounts (password managed by Terraform)
resource "lldap_user" "service_accounts" {
  for_each = {
    for username, user in local.users_config.users : username => user
    if lookup(user, "is_service_account", false)
  }

  username     = each.key
  email        = each.value.email
  display_name = each.value.display_name
  password     = local.service_account_passwords[each.key]
}
