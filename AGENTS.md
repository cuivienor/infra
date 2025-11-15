# Agent Quick Reference

**Repository**: Proxmox homelab IaC (Terraform + Ansible + Bash scripts)  
**Context**: Always read `docs/reference/current-state.md` first, check `notes/wip/CURRENT-STATUS.md` for active work

## Commands

```bash
# Terraform (from repo root)
cd terraform && terraform init && terraform plan && terraform apply

# Ansible (from repo root or ansible/)
ansible-playbook ansible/playbooks/<name>.yml --vault-password-file .vault_pass
ansible-playbook ansible/playbooks/site.yml --tags <tag> --check  # dry-run

# Syntax validation
bash -n scripts/**/*.sh                    # validate bash syntax
terraform fmt -check -recursive terraform/ # check Terraform formatting
ansible-playbook <playbook>.yml --syntax-check
```

## Code Style

- **Terraform**: HCL format (2 spaces), descriptive resource names, use variables for reusable values
- **Ansible**: YAML (2 spaces), handlers in `handlers/`, idempotent tasks, use `--check` mode for testing
- **Bash**: Include shebang `#!/bin/bash`, set -e for error handling, quote variables "$VAR", descriptive comments
- **Naming**: Snake_case for files/vars, descriptive (e.g., `backup.tf`, `ripper.yml`)
- **Paths**: Absolute paths in scripts, relative to repo root in docs (`ansible/roles/...`)
- **Security**: Encrypt secrets with Ansible Vault, never commit `.vault_pass`, `terraform.tfvars`, `*.tfstate`
- **Git commits**: Format `<type>: <description>` (types: feat, fix, docs, refactor, chore)

## Key Conventions

- Scripts run as `media` user (UID 1000)
- Remote execution: `ssh root@homelab "command"` (commands run on client, not Proxmox host)
- Test first: Use CTID 199 for testing before touching production containers (backup/samba/ripper/analyzer/transcoder/jellyfin)
- Documentation: Guides in `docs/guides/`, reference in `docs/reference/`, plans in `docs/plans/`
