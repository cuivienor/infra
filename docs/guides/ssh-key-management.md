# SSH Key Management Guide

Centralized SSH key management for homelab infrastructure.

## Overview

All SSH public keys are stored in `ansible/files/ssh-keys/` and automatically distributed to:
- Proxmox host
- All containers (new and existing)

This provides a single source of truth for SSH access across the entire homelab.

---

## Quick Reference

### Add a New Machine

```bash
# 1. Copy your public key to the ssh-keys directory
cat ~/.ssh/id_ed25519.pub > ansible/files/ssh-keys/new-machine.pub

# 2. Commit to git
git add ansible/files/ssh-keys/new-machine.pub
git commit -m "Add SSH key for new-machine"

# 3. Deploy to all existing infrastructure
cd ansible
ansible-playbook playbooks/sync-ssh-keys.yml

# 4. Future Terraform deployments automatically include it
```

### Remove a Key

```bash
# 1. Disable the key (rename)
mv ansible/files/ssh-keys/old-machine.pub ansible/files/ssh-keys/old-machine.pub.disabled

# 2. Commit and redeploy
git commit -am "Disable SSH key for old-machine"
cd ansible
ansible-playbook playbooks/sync-ssh-keys.yml
```

### Deploy Keys to Specific Host

```bash
cd ansible
ansible-playbook playbooks/sync-ssh-keys.yml --limit homelab
ansible-playbook playbooks/sync-ssh-keys.yml --limit backup
```

---

## Architecture

### Directory Structure

```
homelab-notes/
├── ansible/
│   ├── files/
│   │   └── ssh-keys/           # Central SSH key storage
│   │       ├── laptop.pub      # One file per machine
│   │       ├── desktop.pub
│   │       └── README.md
│   ├── roles/
│   │   └── common/             # Base role for all infrastructure
│   │       ├── tasks/
│   │       │   ├── ssh-keys.yml    # SSH key distribution logic
│   │       │   ├── system.yml
│   │       │   └── packages.yml
│   │       └── defaults/main.yml
│   └── playbooks/
│       ├── sync-ssh-keys.yml   # Dedicated SSH key sync
│       └── site.yml            # Full site configuration
└── terraform/
    ├── ssh_keys.tf             # Reads from ansible/files/ssh-keys/
    └── containers/
        └── backup.tf     # Uses local.ssh_public_keys
```

### How It Works

1. **Storage**: SSH public keys stored as `.pub` files in `ansible/files/ssh-keys/`
2. **Ansible**: `common` role distributes keys to `/root/.ssh/authorized_keys`
3. **Terraform**: Reads same directory and injects keys into new containers
4. **Result**: Consistent SSH access across all infrastructure

---

## Detailed Usage

### Initial Setup (Already Done)

The SSH key infrastructure is already set up with:
- `ansible/files/ssh-keys/laptop.pub` - Your current laptop key
- `common` Ansible role for key distribution
- Terraform integration via `ssh_keys.tf`

### Adding a New Development Machine

**Scenario**: You get a new laptop and want SSH access to your homelab.

```bash
# On the new machine, generate SSH key if needed
ssh-keygen -t ed25519 -C "you@new-laptop"

# Copy the public key to the homelab repo
cat ~/.ssh/id_ed25519.pub > /path/to/homelab-notes/ansible/files/ssh-keys/new-laptop.pub

# Commit to git
cd /path/to/homelab-notes
git add ansible/files/ssh-keys/new-laptop.pub
git commit -m "Add SSH key for new-laptop"
git push

# From any machine with access, deploy the keys
cd ansible
ansible-playbook playbooks/sync-ssh-keys.yml

# Test SSH access from new machine
ssh root@192.168.1.56  # Should work!
```

### Adding a CI/CD Deploy Key

```bash
# Generate dedicated key for CI/CD (no passphrase)
ssh-keygen -t ed25519 -f ~/.ssh/homelab-ci -N "" -C "ci-deploy"

# Add public key to repo
cat ~/.ssh/homelab-ci.pub > ansible/files/ssh-keys/ci-deploy.pub

# Commit and deploy
git add ansible/files/ssh-keys/ci-deploy.pub
git commit -m "Add CI/CD deploy key"
cd ansible
ansible-playbook playbooks/sync-ssh-keys.yml

# Configure CI/CD with private key
# (Store ~/.ssh/homelab-ci as secret in GitHub Actions / GitLab CI)
```

### Temporary Access for a Friend

```bash
# Get their public key
echo "ssh-ed25519 AAAAC3... friend@laptop" > ansible/files/ssh-keys/friend-temp.pub

# Deploy
cd ansible
ansible-playbook playbooks/sync-ssh-keys.yml

# Later, revoke access
mv ansible/files/ssh-keys/friend-temp.pub ansible/files/ssh-keys/friend-temp.pub.disabled
ansible-playbook playbooks/sync-ssh-keys.yml
```

---

## Playbooks

### `sync-ssh-keys.yml`

Syncs SSH keys to all hosts without changing anything else.

```bash
# Sync to all hosts
ansible-playbook playbooks/sync-ssh-keys.yml

# Sync to specific host
ansible-playbook playbooks/sync-ssh-keys.yml --limit homelab

# Sync to group
ansible-playbook playbooks/sync-ssh-keys.yml --limit backup_containers

# Dry run
ansible-playbook playbooks/sync-ssh-keys.yml --check
```

### `site.yml`

Applies full configuration including SSH keys, system settings, and packages.

```bash
# Full site configuration
ansible-playbook playbooks/site.yml

# Only SSH keys
ansible-playbook playbooks/site.yml --tags ssh-keys
```

---

## Security Considerations

### Safe to Commit

✅ **Public keys are safe** to commit to git
- They're designed to be public
- Only grant access when paired with corresponding private key
- No security risk in version control

### Not Safe to Commit

❌ **Never commit private keys**
- Keep private keys on local machines only
- Use SSH agent for key management
- Store private keys in secure locations only

### Key Management Best Practices

1. **One key per machine** - Easier to revoke specific access
2. **Descriptive filenames** - `laptop.pub`, not `id_ed25519.pub`
3. **Remove old keys** - Rename to `.disabled` when no longer needed
4. **Use Ed25519 keys** - Modern, secure, and small
5. **Passphrase protect** - Always use passphrase for personal keys
6. **No passphrase for CI** - CI/CD keys can be unprotected if stored securely

---

## Terraform Integration

### How Terraform Uses SSH Keys

```hcl
# terraform/ssh_keys.tf
locals {
  # Automatically finds all .pub files
  ssh_key_files = fileset("${path.module}/../ansible/files/ssh-keys", "*.pub")

  # Reads content of each file
  ssh_public_keys = [
    for f in local.ssh_key_files :
    trimspace(file("${path.module}/../ansible/files/ssh-keys/${f}"))
  ]
}

# Used in container definitions
resource "proxmox_virtual_environment_container" "example" {
  initialization {
    user_account {
      keys = local.ssh_public_keys  # All keys automatically included
    }
  }
}
```

### Benefits

- **Automatic inclusion**: New containers get all keys automatically
- **No manual configuration**: No need to edit Terraform files
- **Stays in sync**: Same source as Ansible

---

## Troubleshooting

### Keys not working after deployment

```bash
# Check if keys were deployed
ssh root@192.168.1.56 "cat /root/.ssh/authorized_keys"

# Check file permissions
ssh root@192.168.1.56 "ls -la /root/.ssh/"

# Re-run with verbose output
cd ansible
ansible-playbook playbooks/sync-ssh-keys.yml -vv
```

### Role not found error

```bash
# Must run from ansible directory
cd ansible  # Important!
ansible-playbook playbooks/sync-ssh-keys.yml
```

### Terraform doesn't see new keys

```bash
# Verify Terraform finds the keys
cd terraform
terraform console
> local.ssh_public_keys
> local.ssh_key_files
```

---

## Advanced Usage

### Deploy Keys to Specific User

By default, keys go to `root`. To deploy to other users:

```yaml
# In playbook or role invocation
- role: common
  vars:
    ssh_authorized_keys_users:
      - root
      - media
      - someuser
```

### Custom SSH Keys Directory

```yaml
# In defaults or vars
ssh_keys_directory: "/custom/path/to/keys"
```

### Exclude Specific Keys

```bash
# Rename to exclude from deployment
mv ansible/files/ssh-keys/old-key.pub ansible/files/ssh-keys/old-key.pub.disabled

# Or delete entirely
rm ansible/files/ssh-keys/old-key.pub
```

---

## Integration with Other Tools

### With `pct exec`

```bash
# SSH not working? Use pct exec as fallback
pct exec 300 -- bash

# Then manually check authorized_keys
cat /root/.ssh/authorized_keys
```

### With Ansible Inventory

```yaml
# ansible/inventory/hosts.yml
all:
  vars:
    ansible_user: root
    ansible_ssh_private_key_file: ~/.ssh/id_ed25519
```

### With Git Hooks

```bash
# .git/hooks/post-commit
#!/bin/bash
if git diff-tree --no-commit-id --name-only -r HEAD | grep -q "ansible/files/ssh-keys"; then
  echo "SSH keys changed - remember to run: ansible-playbook playbooks/sync-ssh-keys.yml"
fi
```

---

## Related Documentation

- `ansible/files/ssh-keys/README.md` - SSH keys directory documentation
- `ansible/roles/common/README.md` - Common role documentation
- `docs/reference/current-state.md` - Overall IaC strategy

---

## Summary

**Single source of truth**: `ansible/files/ssh-keys/`
**Distribution method**: Ansible `common` role + Terraform `local.ssh_public_keys`
**Add new machine**: Drop `.pub` file + run Ansible playbook
**Remove access**: Rename to `.disabled` + run Ansible playbook

This system provides secure, centralized, and version-controlled SSH access management for your entire homelab.
