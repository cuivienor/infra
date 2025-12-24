---
name: ansible-workflow
description: Use when making Ansible changes - enforces check/apply/verify workflow
---

# Ansible Workflow

## When to Use

Use this skill when:
- Modifying Ansible roles or playbooks
- Installing/configuring software on containers
- Managing services, users, or files via Ansible
- Working with Ansible Vault secrets

## Workflow Checklist

### 1. Navigate to ansible/

**All commands must run from ansible/ directory:**

```bash
cd ansible
```

### 2. Identify Target

Determine what you're modifying:
- **Playbook**: `playbooks/<service>.yml`
- **Role**: `roles/<name>/`
- **Inventory**: `inventory/hosts.yml`
- **Secrets**: `vars/*_secrets.yml`

### 3. Make Changes

Follow conventions:
- Tasks must be idempotent
- Use FQCN (`ansible.builtin.apt` not `apt`)
- Add `name:` to all tasks
- Notify handlers for service restarts

### 4. Lint

```bash
ansible-lint --offline
```

Fix any issues before proceeding.

### 5. Syntax Check

```bash
ansible-playbook playbooks/<service>.yml --syntax-check
```

### 6. Dry Run (REQUIRED)

**Always check before apply:**

```bash
ansible-playbook playbooks/<service>.yml --check
```

Review output:
- Yellow = would change
- Green = ok (no change)
- Red = error

### 7. Present Changes to User

Before applying, summarize:
- Tasks that would change
- Services that would restart
- Any errors or warnings

Ask: "Does this look correct?"

### 8. Apply

Only after user approval:

```bash
ansible-playbook playbooks/<service>.yml
```

**For long-running playbooks** (jellyfin, transcoder, proxmox-host):
- Use 600000ms timeout
- Don't assume failure if slow
- Wait for completion

### 9. Verify

After apply:
- SSH to target and verify changes
- Check service status: `systemctl status <service>`
- Review logs if needed: `journalctl -u <service>`

## Common Patterns

### Modify Existing Role

1. Edit files in `roles/<name>/`
2. Run workflow above targeting relevant playbook
3. Verify changes applied correctly

### Add New Role

1. Create `roles/<name>/` with standard structure
2. Add role to relevant playbook
3. Run workflow above

### Edit Vault Secrets

```bash
ansible-vault edit vars/<service>_secrets.yml
```

Secrets are automatically decrypted via `.vault_pass`.

### Target Specific Hosts

```bash
ansible-playbook playbooks/site.yml --limit ripper
```

### Run Specific Tags

```bash
ansible-playbook playbooks/<service>.yml --tags packages,config
```

## Role Structure Reminder

```
roles/<name>/
├── tasks/main.yml       # Task entry point
├── handlers/main.yml    # Service handlers
├── defaults/main.yml    # Default variables
├── templates/           # Jinja2 templates
└── files/               # Static files
```

## Never Do

- Apply without dry-run (`--check`) first
- Skip user approval for changes
- Run from wrong directory (must be ansible/)
- Create non-idempotent tasks
- Commit unencrypted secrets
- Edit .vault_pass (gitignored for a reason)
