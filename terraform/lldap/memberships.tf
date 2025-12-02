# LLDAP Group Memberships
# Dynamically created from terraform/users.yaml

# LLDAP built-in groups have fixed numeric IDs:
# - lldap_admin = 1
# - lldap_password_manager = 2
# - lldap_strict_readonly = 3

# Look up the built-in lldap_password_manager group
data "lldap_group" "password_manager" {
  id = 2
}

# Flatten user-group relationships from users.yaml
locals {
  memberships = flatten([
    for username, user in local.users_config.users : [
      for group in user.groups : {
        user  = username
        group = group
      }
      if group != "service_accounts" # Skip meta-groups that don't have LLDAP representation
    ]
  ])
}

# Create group memberships from users.yaml
resource "lldap_member" "memberships" {
  for_each = {
    for m in local.memberships : "${m.group}:${m.user}" => m
  }

  group_id = lldap_group.groups[each.value.group].id
  user_id = coalesce(
    try(lldap_user.users[each.value.user].username, null),
    try(lldap_user.service_accounts[each.value.user].username, null)
  )
}

# Authelia service account needs password_manager permissions
# This allows it to query users and reset passwords via LDAP
resource "lldap_member" "authelia_password_manager" {
  group_id = data.lldap_group.password_manager.id
  user_id  = lldap_user.service_accounts["authelia"].username
}
