# LLDAP Users
#
# IMPORTANT: User passwords are managed with lifecycle { ignore_changes = [password] }
# This means:
# - Initial creation uses var.initial_user_password
# - After user changes password via Authelia, Terraform won't overwrite it
# - To force a password reset, use taint or remove from state

# Service account for Authelia
# This account is used by Authelia to query LDAP and reset passwords
# NOTE: No ignore_changes on password - we control this password
resource "lldap_user" "authelia_svc" {
  username     = "authelia"
  email        = "authelia@paniland.com"
  display_name = "Authelia Service Account"
  first_name   = "Authelia"
  last_name    = "Service"
  password     = var.authelia_service_password
}

# Human users
# Each user gets initial_user_password on creation
# After they reset their password via Authelia, it's preserved

resource "lldap_user" "peter" {
  username     = "peter"
  email        = "peter@petrovs.io"
  display_name = "Peter"
  first_name   = "Peter"
  last_name    = "Petrov"
  password     = var.initial_user_password

  lifecycle {
    ignore_changes = [password]
  }
}

# Add more users here following the same pattern:
#
# resource "lldap_user" "username" {
#   username     = "username"
#   email        = "user@example.com"
#   display_name = "Display Name"
#   first_name   = "First"
#   last_name    = "Last"
#   password     = var.initial_user_password
#
#   lifecycle {
#     ignore_changes = [password]
#   }
# }
