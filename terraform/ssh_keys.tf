# SSH Key Management for Terraform
# Reads SSH public keys from centralized location: ansible/files/ssh-keys/

locals {
  # Find all .pub files in the ssh-keys directory
  ssh_key_files = fileset("${path.module}/../ansible/files/ssh-keys", "*.pub")

  # Read content of each .pub file
  ssh_public_keys = [
    for f in local.ssh_key_files :
    trimspace(file("${path.module}/../ansible/files/ssh-keys/${f}"))
  ]
}
