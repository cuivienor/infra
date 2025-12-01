# LLDAP Group Memberships

# LLDAP built-in groups have fixed numeric IDs:
# - lldap_admin = 1
# - lldap_password_manager = 2
# - lldap_strict_readonly = 3

# Look up the built-in lldap_password_manager group
data "lldap_group" "password_manager" {
  id = 2
}

# Authelia service account needs password_manager permissions
# This allows it to query users and reset passwords via LDAP
resource "lldap_member" "authelia_password_manager" {
  group_id = data.lldap_group.password_manager.id
  user_id  = lldap_user.authelia_svc.username
}

# Peter is an admin
resource "lldap_member" "peter_admins" {
  group_id = lldap_group.admins.id
  user_id  = lldap_user.peter.username
}

resource "lldap_member" "peter_users" {
  group_id = lldap_group.users.id
  user_id  = lldap_user.peter.username
}
