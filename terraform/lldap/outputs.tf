# Outputs for LLDAP user management

output "authelia_service_account_dn" {
  description = "DN for Authelia service account (use in Authelia LDAP config)"
  value       = "uid=${lldap_user.authelia_svc.username},ou=people,dc=paniland,dc=com"
}

output "users" {
  description = "List of managed users"
  value = [
    lldap_user.peter.username,
    lldap_user.authelia_svc.username,
  ]
}

output "groups" {
  description = "List of managed groups"
  value = [
    lldap_group.admins.display_name,
    lldap_group.users.display_name,
  ]
}
