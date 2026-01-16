# Ansible Zone

Service configuration for LXC containers. **Always run from `ansible/` directory.**

## STRUCTURE

```
ansible/
├── playbooks/           # Entry points (22 playbooks)
│   ├── site.yml         # All containers + common role
│   └── <service>.yml    # Per-service playbooks
├── roles/               # Reusable modules (15+ roles)
├── inventory/hosts.yml  # Host IPs and CTIDs
├── vars/*_secrets.yml   # Vault-encrypted secrets
└── files/ssh-keys/      # Shared with Terraform
```

## COMMANDS

```bash
cd ansible

# Dry-run first (ALWAYS)
ansible-playbook playbooks/<service>.yml --check

# Apply
ansible-playbook playbooks/<service>.yml

# With tags
ansible-playbook playbooks/site.yml --tags common,packages
```

## LONG-RUNNING PLAYBOOKS

These take 5-10+ minutes (use 600000ms timeout):
- `jellyfin.yml` - Media server install
- `transcoder.yml` - FFmpeg + Intel QSV
- `proxmox-host.yml` - Host maintenance

## VAULT SECRETS

```bash
ansible-vault edit vars/backup_secrets.yml   # Edit
ansible-vault view vars/backup_secrets.yml   # View
ansible-vault encrypt vars/new_secrets.yml   # New file
```

Password: `.vault_pass` (gitignored → Bitwarden)

## ROLE LAYOUT

```
roles/<name>/
├── tasks/main.yml       # Entry point
├── handlers/main.yml    # Service restarts
├── defaults/main.yml    # Default vars
├── templates/*.j2       # Jinja2 configs
└── files/               # Static files
```

## CONVENTIONS

**FQCN required**: `ansible.builtin.apt` not `apt`

**Idempotency mandatory**:
```yaml
# Good
- ansible.builtin.apt: { name: nginx, state: present }

# Bad - not idempotent
- ansible.builtin.shell: echo "config" >> /etc/app.conf
```

**Handlers**:
```yaml
# Task notifies handler
- ansible.builtin.template: { src: config.j2, dest: /etc/app/config }
  notify: Restart app

# Handler runs once at end
- name: Restart app
  ansible.builtin.systemd: { name: app, state: restarted }
```

## ANTI-PATTERNS

- Running from wrong directory → Always `cd ansible`
- Shell commands when modules exist → Use builtin modules
- Missing `name:` on tasks → Required by linter
- Non-idempotent tasks → Use lineinfile/template

## LINTING

```bash
ansible-lint --offline            # Full
ansible-lint playbooks/site.yml   # Single file
```

## KEY FILES

| File | Purpose |
|------|---------|
| `ansible.cfg` | Vault password path, inventory |
| `inventory/hosts.yml` | All hosts with IPs |
| `roles/common/` | Base role for all containers |
| `vars/*_secrets.yml` | Encrypted credentials |
