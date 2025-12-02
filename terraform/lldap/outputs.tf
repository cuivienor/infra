# Outputs for LLDAP user management

output "authelia_service_account_dn" {
  description = "DN for Authelia service account (use in Authelia LDAP config)"
  value       = "uid=${lldap_user.service_accounts["authelia"].username},ou=people,dc=paniland,dc=com"
}

output "users" {
  description = "List of managed human users"
  value       = [for u in lldap_user.users : u.username]
}

output "service_accounts" {
  description = "List of managed service accounts"
  value       = [for u in lldap_user.service_accounts : u.username]
}

output "groups" {
  description = "List of managed groups"
  value       = [for g in lldap_group.groups : g.display_name]
}
