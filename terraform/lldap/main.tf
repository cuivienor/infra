# LLDAP User Management
# Manages users, groups, and memberships in LLDAP via Terraform

terraform {
  required_version = ">= 1.0"

  required_providers {
    lldap = {
      source  = "tasansga/lldap"
      version = "~> 0.2"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1"
    }
  }
}

provider "lldap" {
  http_url = "http://192.168.1.114:17170"
  ldap_url = "ldap://192.168.1.114:3890"
  username = "admin"
  password = local.lldap_admin_password
  base_dn  = "dc=paniland,dc=com"
}
