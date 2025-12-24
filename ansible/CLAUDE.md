# Ansible Zone

Zone-specific guidance for working with Ansible in this monorepo.

## Directory Structure

```
ansible/
├── playbooks/           # Entry points - one per service/purpose
│   ├── site.yml         # Apply common role to all
│   ├── containers-base.yml
│   └── <service>.yml    # Service-specific playbooks
├── roles/               # Reusable configuration modules
│   └── <role>/
│       ├── tasks/main.yml
│       ├── handlers/main.yml
│       ├── defaults/main.yml
│       ├── templates/
│       └── files/
├── inventory/
│   └── hosts.yml        # Host definitions with IPs and CTIDs
├── vars/
│   └── *_secrets.yml    # Vault-encrypted secrets
├── files/
│   └── ssh-keys/        # Public keys (shared with Terraform)
└── ansible.cfg          # Config (vault password file, etc.)
```

## Running Playbooks

**Always run from ansible/ directory:**

```bash
cd ansible

# Dry-run first (safe preview)
ansible-playbook playbooks/<service>.yml --check

# Apply changes
ansible-playbook playbooks/<service>.yml

# With specific tags
ansible-playbook playbooks/site.yml --tags common,packages

# Syntax check only
ansible-playbook playbooks/<service>.yml --syntax-check
```

## Long-Running Playbooks

These playbooks take 5-10+ minutes due to package installs or compilations:
- `jellyfin.yml` - Jellyfin media server
- `transcoder.yml` - FFmpeg with Intel QSV
- `proxmox-host.yml` - Host maintenance tasks

**When running these, use 600000ms (10 min) timeout.** Don't assume failure if slow.

## Vault Secrets

Secrets are encrypted with Ansible Vault:

```bash
# Edit encrypted file
ansible-vault edit vars/backup_secrets.yml

# Encrypt new file
ansible-vault encrypt vars/new_secrets.yml

# View without editing
ansible-vault view vars/backup_secrets.yml
```

**Password location:** `.vault_pass` (gitignored, restore from Bitwarden)

Access in playbooks:
```yaml
- name: Include secrets
  include_vars: "{{ playbook_dir }}/../vars/service_secrets.yml"
```

## Role Structure

Standard role layout:

```
roles/<name>/
├── tasks/
│   └── main.yml         # Task entry point
├── handlers/
│   └── main.yml         # Service restart handlers
├── defaults/
│   └── main.yml         # Default variables (override in playbook)
├── templates/
│   └── config.j2        # Jinja2 templates
├── files/
│   └── static_file      # Static files to copy
└── meta/
    └── main.yml         # Dependencies on other roles
```

## Idempotency Rules

**All tasks MUST be idempotent** - running twice produces same result:

```yaml
# Good: Idempotent
- name: Ensure package installed
  ansible.builtin.apt:
    name: nginx
    state: present

# Bad: Not idempotent
- name: Add line to file
  ansible.builtin.shell: echo "config" >> /etc/app.conf
```

Use modules like `lineinfile`, `blockinfile`, `template` instead of shell commands.

## Handler Pattern

Handlers run once at end of play, only if notified:

```yaml
# In tasks/main.yml
- name: Update config
  ansible.builtin.template:
    src: config.j2
    dest: /etc/app/config
  notify: Restart app

# In handlers/main.yml
- name: Restart app
  ansible.builtin.systemd:
    name: app
    state: restarted
```

## Tag Usage

Use tags for selective execution:

```yaml
- name: Install packages
  ansible.builtin.apt:
    name: "{{ item }}"
  loop: "{{ packages }}"
  tags: [packages]

- name: Configure service
  ansible.builtin.template:
    src: config.j2
    dest: /etc/app/config
  tags: [config]
```

Run specific tags:
```bash
ansible-playbook playbooks/service.yml --tags packages
ansible-playbook playbooks/service.yml --skip-tags config
```

## Common Pitfalls

1. **Wrong directory**: Always `cd ansible` first. Paths are relative.

2. **Missing vault password**: Check `.vault_pass` exists or run `./scripts/setup-dev.sh --setup-secrets`

3. **Non-idempotent tasks**: Avoid raw shell commands. Use builtin modules.

4. **Forgotten handlers**: Handlers only run if notified AND play succeeds. Check handler names match exactly.

5. **Variable precedence**: defaults < group_vars < host_vars < playbook vars < extra vars. See [Ansible docs](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#understanding-variable-precedence).

## Linting

```bash
cd ansible
ansible-lint --offline           # Full lint
ansible-lint playbooks/site.yml  # Single file
```

Fix common issues:
- `name:` required on all tasks
- Use FQCN (`ansible.builtin.apt` not `apt`)
- Avoid `command`/`shell` when modules exist

## Key Files

- `ansible.cfg` - Config including vault_password_file
- `inventory/hosts.yml` - All hosts with ansible_host IPs
- `roles/common/` - Base role applied to all containers
- `vars/*_secrets.yml` - Encrypted credentials
