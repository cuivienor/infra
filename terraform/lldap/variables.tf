# Variables for LLDAP user management

variable "lldap_admin_password" {
  description = "LLDAP admin password"
  type        = string
  sensitive   = true
}

variable "initial_user_password" {
  description = "Initial password for new users (they should change via password reset)"
  type        = string
  sensitive   = true
}

variable "authelia_service_password" {
  description = "Password for the Authelia service account"
  type        = string
  sensitive   = true
}
