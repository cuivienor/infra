# SSH Public Keys

This directory contains SSH public keys for authorized access to homelab infrastructure.

## Purpose

- **Centralized SSH key management** for all homelab hosts and containers
- Keys here are distributed to all infrastructure via Ansible
- Terraform automatically includes these keys in new container deployments

## Structure

- One `.pub` file per machine/user
- Filename indicates the machine/purpose (e.g., `laptop.pub`, `desktop.pub`, `ci-deploy.pub`)
- All `.pub` files in this directory are automatically deployed

## Adding a New Machine

1. Copy your public key to this directory:
   ```bash
   cat ~/.ssh/id_ed25519.pub > ansible/files/ssh-keys/new-machine.pub
   ```

2. Commit to git:
   ```bash
   git add ansible/files/ssh-keys/new-machine.pub
   git commit -m "Add SSH key for new-machine"
   ```

3. Deploy to all existing infrastructure:
   ```bash
   ansible-playbook playbooks/sync-ssh-keys.yml
   ```

4. Future Terraform deployments automatically include the new key

## Removing a Key

1. Delete or rename the file:
   ```bash
   mv ansible/files/ssh-keys/old-machine.pub ansible/files/ssh-keys/old-machine.pub.disabled
   ```

2. Commit and redeploy:
   ```bash
   git commit -am "Disable SSH key for old-machine"
   ansible-playbook playbooks/sync-ssh-keys.yml
   ```

## Security Notes

- ✅ Public keys are safe to commit to git
- ✅ Keys are deployed to `/root/.ssh/authorized_keys` on all hosts/containers
- ✅ No private keys should ever be stored here
- ⚠️ Anyone with access to this repo can see which machines have access

## Current Keys

- `laptop.pub` - Primary development laptop (cuiv@laptop)
