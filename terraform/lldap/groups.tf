# LLDAP Groups

# Custom groups for access control
resource "lldap_group" "admins" {
  display_name = "admins"
}

resource "lldap_group" "users" {
  display_name = "users"
}

# Reference built-in LLDAP groups (these exist automatically)
# lldap_admin - Full admin rights
# lldap_password_manager - Can change user passwords
# lldap_strict_readonly - Read-only access
