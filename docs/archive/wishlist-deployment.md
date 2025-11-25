# Wishlist Application Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy the cmintey/wishlist self-hosted gift registry application on homelab infrastructure using native Node.js installation in an LXC container.

**Architecture:** Create CT307 unprivileged LXC container (192.168.1.186) running wishlist natively via Node.js 24 + pnpm, with systemd service management. Reverse proxy through existing Caddy instance (CT311) with automatic HTTPS. SQLite database and uploads stored on container disk, backed up via restic to Backblaze B2. Tailscale ACLs grant friends access.

**Tech Stack:**
- Infrastructure: Proxmox LXC (Debian 12), Terraform, Ansible
- Application: Node.js 24.x, pnpm 10+, SvelteKit, Prisma ORM, SQLite
- Reverse Proxy: Caddy with Cloudflare DNS-01 challenge
- Access: Tailscale VPN + public HTTPS via wishlist.paniland.com

---

## Prerequisites

- Terraform installed with Proxmox provider configured
- Ansible installed with vault password in `.vault_pass`
- SSH keys in `ansible/files/ssh-keys/` directory
- Caddy already running on CT311 with Cloudflare API token
- Tailscale ACLs managed via `terraform/tailscale.tf`

---

## Task 1: Create Terraform Container Definition

**Goal:** Define CT307 LXC container with proper networking and resource allocation.

**Files:**
- Create: `terraform/wishlist.tf`

### Step 1: Create wishlist.tf with container definition

```hcl
# CT307: Wishlist Application
# Self-hosted gift registry and wishlist sharing
# Native Node.js deployment with systemd management

resource "proxmox_virtual_environment_container" "wishlist" {
  description = "Wishlist - self-hosted gift registry application"
  node_name   = "homelab"
  vm_id       = 307

  # Container initialization
  started = true

  # Unprivileged container (no special hardware needs)
  unprivileged = true

  initialization {
    hostname = "wishlist"

    ip_config {
      ipv4 {
        address = "192.168.1.186/24"
        gateway = "192.168.1.1"
      }
    }

    dns {
      domain  = var.dns_domain
      servers = var.dns_servers
    }

    user_account {
      # SSH keys automatically loaded from ansible/files/ssh-keys/
      keys = local.ssh_public_keys
    }
  }

  # Network configuration
  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  # Operating system
  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  # Resource allocation
  cpu {
    cores = 2 # Sufficient for SvelteKit SSR + web scraping
  }

  memory {
    dedicated = 2048 # 2GB RAM for Node.js app + Prisma
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 20 # 20GB for Node.js, deps, SQLite DB, uploads
  }

  # Features
  features {
    nesting = false # Not needed for Node.js app
  }

  # Tags
  tags = ["web", "iac", "wishlist", "personal"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      # Ignore changes to these to prevent Terraform from recreating on minor changes
      initialization[0].user_account,
    ]
  }
}
```

### Step 2: Run terraform fmt to format the file

**Command:**
```bash
cd terraform
terraform fmt wishlist.tf
```

**Expected output:**
```
wishlist.tf
```

### Step 3: Validate terraform configuration

**Command:**
```bash
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

### Step 4: Preview terraform changes

**Command:**
```bash
terraform plan
```

**Expected output:** Shows plan to create 1 new resource (`proxmox_virtual_environment_container.wishlist`)

### Step 5: Apply terraform to create container

**Command:**
```bash
terraform apply
```

**Interactive:** Type `yes` when prompted

**Expected output:** Container CT307 created and started on Proxmox

### Step 6: Verify container is running

**Command:**
```bash
ssh cuiv@homelab "sudo pct list" | grep 307
```

**Expected output:**
```
307       running       192.168.1.186    wishlist
```

### Step 7: Commit terraform changes

```bash
cd /home/cuiv/dev/homelab-notes
git add terraform/wishlist.tf
git commit -m "feat: add CT307 wishlist container terraform definition

- CTID 307, IP 192.168.1.186 (Personal & Productivity range)
- Unprivileged Debian 12 container
- 2 CPU cores, 2GB RAM, 20GB disk
- Configured for native Node.js deployment"
```

---

## Task 2: Create Ansible Wishlist Role Structure

**Goal:** Set up the Ansible role directory structure for wishlist deployment.

**Files:**
- Create: `ansible/roles/wishlist/tasks/main.yml`
- Create: `ansible/roles/wishlist/tasks/install.yml`
- Create: `ansible/roles/wishlist/tasks/deploy.yml`
- Create: `ansible/roles/wishlist/tasks/systemd.yml`
- Create: `ansible/roles/wishlist/templates/wishlist.service.j2`
- Create: `ansible/roles/wishlist/templates/wishlist.env.j2`
- Create: `ansible/roles/wishlist/defaults/main.yml`
- Create: `ansible/roles/wishlist/handlers/main.yml`

### Step 1: Create role directory structure

**Command:**
```bash
mkdir -p ansible/roles/wishlist/{tasks,templates,defaults,handlers,files}
```

### Step 2: Create defaults/main.yml with role variables

```yaml
---
# Default variables for wishlist role

# Application
wishlist_user: "wishlist"
wishlist_group: "wishlist"
wishlist_home: "/opt/wishlist"
wishlist_repo_url: "https://github.com/cmintey/wishlist.git"
wishlist_repo_version: "main"  # Change to specific tag for stability

# Node.js
nodejs_version: "24"  # Major version
nodejs_distro: "nodistro"  # For Debian

# Service
wishlist_port: 3280
wishlist_origin: "https://wishlist.paniland.com"
wishlist_token_time: "72"  # Hours
wishlist_default_currency: "USD"

# Database
wishlist_data_dir: "{{ wishlist_home }}/data"
wishlist_uploads_dir: "{{ wishlist_home }}/uploads"
wishlist_db_path: "{{ wishlist_data_dir }}/prod.db"

# Build
wishlist_build_dir: "{{ wishlist_home }}/build"
wishlist_node_modules_dir: "{{ wishlist_home }}/node_modules"
```

### Step 3: Create handlers/main.yml

```yaml
---
# Handlers for wishlist role

- name: Restart wishlist
  ansible.builtin.systemd:
    name: wishlist
    state: restarted
    daemon_reload: true
  become: true

- name: Reload wishlist
  ansible.builtin.systemd:
    name: wishlist
    state: reloaded
  become: true
```

### Step 4: Commit role structure

```bash
git add ansible/roles/wishlist/
git commit -m "feat: create wishlist ansible role structure

- Set up tasks, templates, defaults, handlers directories
- Define default variables for Node.js 24 + pnpm deployment
- Configure application paths and service settings"
```

---

## Task 3: Implement Wishlist Role - Node.js Installation

**Goal:** Install Node.js 24.x and pnpm from official sources.

**Files:**
- Create: `ansible/roles/wishlist/tasks/install.yml`

### Step 1: Create install.yml task file

```yaml
---
# Install Node.js and pnpm for wishlist

- name: Install Node.js prerequisites
  ansible.builtin.apt:
    name:
      - ca-certificates
      - curl
      - gnupg
      - git
      - build-essential  # May be needed for native modules
    state: present
    update_cache: true
  become: true

- name: Create keyrings directory
  ansible.builtin.file:
    path: /etc/apt/keyrings
    state: directory
    mode: '0755'
  become: true

- name: Download NodeSource GPG key
  ansible.builtin.get_url:
    url: "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
    dest: /etc/apt/keyrings/nodesource.asc
    mode: '0644'
  become: true

- name: Add NodeSource repository
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/nodesource.asc] https://deb.nodesource.com/node_{{ nodejs_version }}.x {{ ansible_distribution_release }} main"
    state: present
    filename: nodesource
  become: true

- name: Install Node.js
  ansible.builtin.apt:
    name: nodejs
    state: present
    update_cache: true
  become: true

- name: Verify Node.js version
  ansible.builtin.command: node --version
  register: node_version_check
  changed_when: false

- name: Display Node.js version
  ansible.builtin.debug:
    msg: "Installed Node.js {{ node_version_check.stdout }}"

- name: Install pnpm via npm
  ansible.builtin.command: npm install -g pnpm
  args:
    creates: /usr/bin/pnpm
  become: true

- name: Verify pnpm version
  ansible.builtin.command: pnpm --version
  register: pnpm_version_check
  changed_when: false

- name: Display pnpm version
  ansible.builtin.debug:
    msg: "Installed pnpm {{ pnpm_version_check.stdout }}"

- name: Create wishlist group
  ansible.builtin.group:
    name: "{{ wishlist_group }}"
    system: true
  become: true

- name: Create wishlist user
  ansible.builtin.user:
    name: "{{ wishlist_user }}"
    group: "{{ wishlist_group }}"
    home: "{{ wishlist_home }}"
    shell: /bin/bash
    system: true
    create_home: true
  become: true

- name: Create wishlist data directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ wishlist_user }}"
    group: "{{ wishlist_group }}"
    mode: '0755'
  loop:
    - "{{ wishlist_data_dir }}"
    - "{{ wishlist_uploads_dir }}"
  become: true
```

### Step 2: Commit install tasks

```bash
git add ansible/roles/wishlist/tasks/install.yml
git commit -m "feat: add Node.js 24 and pnpm installation tasks

- Install Node.js 24.x from NodeSource repository
- Install pnpm package manager globally
- Create wishlist user and group
- Set up data and uploads directories"
```

---

## Task 4: Implement Wishlist Role - Application Deployment

**Goal:** Clone repository, install dependencies, and build application.

**Files:**
- Create: `ansible/roles/wishlist/tasks/deploy.yml`

### Step 1: Create deploy.yml task file

```yaml
---
# Deploy wishlist application from GitHub

- name: Clone wishlist repository
  ansible.builtin.git:
    repo: "{{ wishlist_repo_url }}"
    dest: "{{ wishlist_home }}/repo"
    version: "{{ wishlist_repo_version }}"
    force: false  # Don't overwrite local changes
  become: true
  become_user: "{{ wishlist_user }}"
  notify: Restart wishlist

- name: Install Node.js dependencies
  ansible.builtin.command:
    cmd: pnpm install --prod=false
    chdir: "{{ wishlist_home }}/repo"
  become: true
  become_user: "{{ wishlist_user }}"
  changed_when: true  # Always consider changed to ensure rebuild
  notify: Restart wishlist

- name: Generate Prisma client
  ansible.builtin.command:
    cmd: pnpm prisma generate
    chdir: "{{ wishlist_home }}/repo"
  become: true
  become_user: "{{ wishlist_user }}"
  changed_when: true
  environment:
    DATABASE_URL: "file:{{ wishlist_db_path }}"

- name: Build wishlist application
  ansible.builtin.command:
    cmd: pnpm build
    chdir: "{{ wishlist_home }}/repo"
  become: true
  become_user: "{{ wishlist_user }}"
  changed_when: true
  notify: Restart wishlist

- name: Prune development dependencies
  ansible.builtin.command:
    cmd: pnpm install --prod
    chdir: "{{ wishlist_home }}/repo"
  become: true
  become_user: "{{ wishlist_user }}"
  changed_when: true

- name: Check if database exists
  ansible.builtin.stat:
    path: "{{ wishlist_db_path }}"
  register: db_file

- name: Deploy Prisma migrations (initial setup)
  ansible.builtin.command:
    cmd: pnpm prisma migrate deploy
    chdir: "{{ wishlist_home }}/repo"
  become: true
  become_user: "{{ wishlist_user }}"
  when: not db_file.stat.exists
  environment:
    DATABASE_URL: "file:{{ wishlist_db_path }}"

- name: Seed database (initial setup)
  ansible.builtin.command:
    cmd: pnpm prisma db seed
    chdir: "{{ wishlist_home }}/repo"
  become: true
  become_user: "{{ wishlist_user }}"
  when: not db_file.stat.exists
  failed_when: false  # Seed might not be defined
  environment:
    DATABASE_URL: "file:{{ wishlist_db_path }}"

- name: Run database patches (initial setup)
  ansible.builtin.command:
    cmd: pnpm db:patch
    chdir: "{{ wishlist_home }}/repo"
  become: true
  become_user: "{{ wishlist_user }}"
  when: not db_file.stat.exists
  failed_when: false  # Patch might not exist yet
  environment:
    DATABASE_URL: "file:{{ wishlist_db_path }}"
```

### Step 2: Commit deploy tasks

```bash
git add ansible/roles/wishlist/tasks/deploy.yml
git commit -m "feat: add wishlist application deployment tasks

- Clone wishlist repository from GitHub
- Install dependencies with pnpm
- Generate Prisma client and build SvelteKit app
- Deploy database migrations on initial setup
- Prune dev dependencies for production"
```

---

## Task 5: Implement Wishlist Role - Systemd Service

**Goal:** Create systemd service to manage wishlist as a daemon.

**Files:**
- Create: `ansible/roles/wishlist/tasks/systemd.yml`
- Create: `ansible/roles/wishlist/templates/wishlist.service.j2`
- Create: `ansible/roles/wishlist/templates/wishlist.env.j2`

### Step 1: Create systemd.yml task file

```yaml
---
# Configure wishlist systemd service

- name: Create wishlist environment file
  ansible.builtin.template:
    src: wishlist.env.j2
    dest: /etc/default/wishlist
    owner: root
    group: root
    mode: '0600'  # Restrictive permissions for sensitive data
  become: true
  notify: Restart wishlist

- name: Create wishlist systemd service
  ansible.builtin.template:
    src: wishlist.service.j2
    dest: /etc/systemd/system/wishlist.service
    owner: root
    group: root
    mode: '0644'
  become: true
  notify: Restart wishlist

- name: Reload systemd daemon
  ansible.builtin.systemd:
    daemon_reload: true
  become: true

- name: Enable and start wishlist service
  ansible.builtin.systemd:
    name: wishlist
    state: started
    enabled: true
  become: true
```

### Step 2: Create wishlist.env.j2 template

```jinja2
# Environment variables for wishlist application
# Managed by Ansible - DO NOT EDIT MANUALLY

# Application configuration
ORIGIN={{ wishlist_origin }}
TOKEN_TIME={{ wishlist_token_time }}
DEFAULT_CURRENCY={{ wishlist_default_currency }}

# Database
DATABASE_URL=file:{{ wishlist_db_path }}

# Node.js
NODE_ENV=production
```

### Step 3: Create wishlist.service.j2 template

```jinja2
[Unit]
Description=Wishlist - Self-hosted gift registry
Documentation=https://github.com/cmintey/wishlist
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User={{ wishlist_user }}
Group={{ wishlist_group }}
WorkingDirectory={{ wishlist_home }}/repo
EnvironmentFile=/etc/default/wishlist

# Run migrations before starting app
ExecStartPre=/usr/bin/pnpm prisma migrate deploy
ExecStartPre=/usr/bin/pnpm prisma db seed
ExecStartPre=/bin/sh -c 'pnpm db:patch || true'

# Start application
ExecStart=/usr/bin/node build

# Process management
Restart=on-failure
RestartSec=10s
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=30s

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths={{ wishlist_home }}

# Resource limits
MemoryMax=1G
CPUQuota=150%

[Install]
WantedBy=multi-user.target
```

### Step 4: Commit systemd configuration

```bash
git add ansible/roles/wishlist/tasks/systemd.yml
git add ansible/roles/wishlist/templates/wishlist.service.j2
git add ansible/roles/wishlist/templates/wishlist.env.j2
git commit -m "feat: add wishlist systemd service configuration

- Create systemd service with automatic restarts
- Run Prisma migrations on service start
- Configure environment variables for production
- Add security hardening and resource limits"
```

---

## Task 6: Wire Up Wishlist Role Main Tasks

**Goal:** Create main.yml that imports all task files in correct order.

**Files:**
- Create: `ansible/roles/wishlist/tasks/main.yml`

### Step 1: Create main.yml with task imports

```yaml
---
# Main tasks for wishlist role

- name: Import installation tasks
  ansible.builtin.import_tasks: install.yml
  tags: ['wishlist', 'install', 'nodejs']

- name: Import deployment tasks
  ansible.builtin.import_tasks: deploy.yml
  tags: ['wishlist', 'deploy', 'build']

- name: Import systemd tasks
  ansible.builtin.import_tasks: systemd.yml
  tags: ['wishlist', 'systemd', 'service']
```

### Step 2: Commit main tasks file

```bash
git add ansible/roles/wishlist/tasks/main.yml
git commit -m "feat: wire up wishlist role main tasks

- Import install, deploy, and systemd tasks
- Tag tasks for selective execution
- Complete wishlist role implementation"
```

---

## Task 7: Create Wishlist Ansible Playbook

**Goal:** Create playbook to apply wishlist role to CT307.

**Files:**
- Create: `ansible/playbooks/wishlist.yml`
- Modify: `ansible/inventory/hosts.yml` (add wishlist container)

### Step 1: Add wishlist to inventory

Open `ansible/inventory/hosts.yml` and add after the `proxy_containers` section:

```yaml
    wishlist_containers:
      hosts:
        wishlist:
          ansible_host: 192.168.1.186
          ansible_user: root
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
          container_id: 307
```

Also add `wishlist_containers` to the `lxc_containers` children list:

```yaml
    lxc_containers:
      children:
        backup_containers:
        samba_containers:
        ripper_containers:
        analyzer_containers:
        transcoder_containers:
        jellyfin_containers:
        dns_containers:
        proxy_containers:
        wishlist_containers:
```

### Step 2: Create wishlist.yml playbook

```yaml
---
# Playbook to configure wishlist container
# Usage: ansible-playbook playbooks/wishlist.yml --vault-password-file .vault_pass

- name: Configure wishlist container
  hosts: wishlist
  become: true

  vars:
    # Wishlist-specific overrides (if needed)
    wishlist_repo_version: "main"  # Change to tag for specific version

  pre_tasks:
    - name: Wait for container to be ready
      ansible.builtin.wait_for_connection:
        timeout: 60

    - name: Gather facts
      ansible.builtin.setup:

  roles:
    - role: common
      vars:
        media_user_enabled: false       # Wishlist runs as dedicated user
        homelab_shell_enabled: true     # Enable zsh for troubleshooting
      tags: ['common', 'base']

    - role: wishlist
      tags: ['wishlist']

  post_tasks:
    - name: Wait for wishlist service to be active
      ansible.builtin.systemd:
        name: wishlist
      register: wishlist_service
      until: wishlist_service.status.ActiveState == "active"
      retries: 5
      delay: 5
      tags: ['verify']

    - name: Check wishlist is responding
      ansible.builtin.uri:
        url: "http://{{ ansible_host }}:3280"
        status_code: 200
      register: wishlist_health
      retries: 3
      delay: 5
      until: wishlist_health.status == 200
      tags: ['verify']

    - name: Display wishlist summary
      ansible.builtin.debug:
        msg:
          - "========================================="
          - "CT307 Wishlist Container Configuration Complete"
          - "========================================="
          - ""
          - "Container: wishlist ({{ ansible_host }})"
          - "Local access: http://{{ ansible_host }}:3280"
          - "Public domain: {{ wishlist_origin }}"
          - ""
          - "Application details:"
          - "  - User: wishlist"
          - "  - Install path: /opt/wishlist"
          - "  - Database: /opt/wishlist/data/prod.db"
          - "  - Uploads: /opt/wishlist/uploads"
          - ""
          - "Next steps:"
          - "  1. Configure Caddy reverse proxy (Task 8)"
          - "  2. Update Tailscale ACLs (Task 9)"
          - "  3. Complete first-time setup at {{ wishlist_origin }}"
          - "  4. Create user accounts"
          - ""
          - "Logs: journalctl -u wishlist -f"
          - "========================================="
      tags: ['verify', 'always']
```

### Step 3: Commit playbook and inventory

```bash
git add ansible/inventory/hosts.yml
git add ansible/playbooks/wishlist.yml
git commit -m "feat: create wishlist ansible playbook and inventory

- Add wishlist container to ansible inventory (CT307)
- Create playbook with common + wishlist roles
- Add health checks and verification tasks
- Display post-deployment summary"
```

### Step 4: Run ansible playbook to deploy wishlist

**Command:**
```bash
cd ansible
ansible-playbook playbooks/wishlist.yml --vault-password-file ../.vault_pass
```

**Expected output:** Successful deployment with wishlist service active

### Step 5: Verify wishlist is running

**Command:**
```bash
curl http://192.168.1.186:3280
```

**Expected output:** HTML response from wishlist application (may be redirect to /login)

### Step 6: Check service status

**Command:**
```bash
ssh root@192.168.1.186 "systemctl status wishlist"
```

**Expected output:** Service is active (running)

---

## Task 8: Configure Caddy Reverse Proxy

**Goal:** Add wishlist.paniland.com to Caddy configuration on CT311.

**Files:**
- Modify: `ansible/roles/caddy/defaults/main.yml` or playbook vars

### Step 1: Check current Caddy configuration

**Command:**
```bash
ansible-inventory -i ansible/inventory/hosts.yml --host proxy --yaml
```

**Purpose:** Understand how Caddy proxy targets are configured

### Step 2: Find where caddy_proxy_targets is defined

**Command:**
```bash
grep -r "caddy_proxy_targets" ansible/
```

**Purpose:** Locate the variable definition to add wishlist

### Step 3: Add wishlist to caddy_proxy_targets

Location will vary based on your setup. Most likely in `ansible/playbooks/proxy.yml` or a vars file. Add:

```yaml
caddy_proxy_targets:
  - domain: "jellyfin.paniland.com"
    upstream: "192.168.1.130:8096"
  - domain: "backup.paniland.com"
    upstream: "192.168.1.120:9898"
  - domain: "dns.paniland.com"
    upstream: "192.168.1.110:3000"
    upstream_https: true
  - domain: "proxmox.paniland.com"
    upstream: "192.168.1.100:8006"
    upstream_https: true
  - domain: "wishlist.paniland.com"  # NEW
    upstream: "192.168.1.186:3280"   # NEW
```

### Step 4: Run Caddy playbook to apply changes

**Command:**
```bash
ansible-playbook ansible/playbooks/proxy.yml --vault-password-file .vault_pass --tags caddy
```

**Expected output:** Caddy configuration updated and service reloaded

### Step 5: Verify Caddy configuration

**Command:**
```bash
ssh root@192.168.1.111 "caddy validate --config /etc/caddy/Caddyfile"
```

**Expected output:** Configuration is valid

### Step 6: Test HTTPS access

**Command:**
```bash
curl -I https://wishlist.paniland.com
```

**Expected output:** HTTP 200 or 302 (redirect to login)

### Step 7: Commit Caddy configuration

```bash
git add ansible/playbooks/proxy.yml  # Or wherever you modified
git commit -m "feat: add wishlist.paniland.com to Caddy reverse proxy

- Configure reverse proxy for CT307 wishlist (192.168.1.186:3280)
- Automatic HTTPS via Cloudflare DNS-01 challenge
- Public access through wishlist.paniland.com"
```

---

## Task 9: Configure Tailscale Access Control

**Goal:** Add wishlist to Tailscale ACLs for friend access.

**Files:**
- Modify: `terraform/tailscale.tf`

### Step 1: Review current Tailscale ACL structure

**Command:**
```bash
grep -A 20 "acls" terraform/tailscale.tf
```

**Purpose:** Understand existing ACL rules for friends group

### Step 2: Add wishlist to ACL rules

In `terraform/tailscale.tf`, find the ACL section and add wishlist. Example:

```hcl
  acl = jsonencode({
    acls = [
      {
        action = "accept"
        src    = ["group:admins"]
        dst    = ["*:*"]
      },
      {
        action = "accept"
        src    = ["group:friends"]
        dst    = [
          "192.168.1.130:8096",  # Jellyfin
          "192.168.1.186:3280",  # Wishlist (NEW)
        ]
      }
    ]
    # ... rest of config
  })
```

### Step 3: Validate Terraform configuration

**Command:**
```bash
cd terraform
terraform validate
```

**Expected output:** Success! The configuration is valid.

### Step 4: Preview Tailscale changes

**Command:**
```bash
terraform plan
```

**Expected output:** Shows modification to tailscale ACL resource

### Step 5: Apply Tailscale changes

**Command:**
```bash
terraform apply
```

**Interactive:** Type `yes` when prompted

**Expected output:** ACL updated successfully

### Step 6: Commit Tailscale configuration

```bash
cd /home/cuiv/dev/homelab-notes
git add terraform/tailscale.tf
git commit -m "feat: add wishlist to Tailscale ACL for friends access

- Allow friends group access to 192.168.1.186:3280
- Enables wishlist access over Tailscale VPN
- Consistent with Jellyfin access pattern"
```

---

## Task 10: Configure Restic Backup

**Goal:** Include wishlist data in restic backup policy.

**Files:**
- Modify: `ansible/roles/restic_backup/defaults/main.yml` or backup-specific vars

### Step 1: Review current backup configuration

**Command:**
```bash
cat ansible/roles/restic_backup/defaults/main.yml | grep -A 10 "backup_paths"
```

**Purpose:** Understand how backup paths are defined

### Step 2: Identify backup approach

Wishlist data is on container disk (not /mnt/storage), so it needs container-level backup.

**Options:**
A. Add wishlist container to container update/backup script
B. Create dedicated wishlist backup in restic role
C. Rely on Proxmox container backups

**Decision:** Add to container-level backups (if implemented) or create new backup policy.

### Step 3: Add wishlist to container backup script

If you have a container backup script in `proxmox_container_updates` or similar, add CT307.

Example addition to backup script:
```bash
# Backup wishlist container data
pct exec 307 -- tar czf /tmp/wishlist-backup.tar.gz /opt/wishlist/data /opt/wishlist/uploads
pct pull 307 /tmp/wishlist-backup.tar.gz /mnt/storage/backups/containers/wishlist-backup.tar.gz
```

### Step 4: Alternative - Document manual backup procedure

Create documentation for backing up wishlist data:

```bash
# Backup wishlist SQLite database and uploads
ssh root@192.168.1.186 "tar czf /tmp/wishlist-data.tar.gz /opt/wishlist/data /opt/wishlist/uploads"
scp root@192.168.1.186:/tmp/wishlist-data.tar.gz ~/backups/
```

### Step 5: Commit backup configuration

```bash
git add ansible/roles/restic_backup/  # Or relevant backup config
git commit -m "feat: add wishlist data to backup strategy

- Include /opt/wishlist/data (SQLite DB) in backups
- Include /opt/wishlist/uploads (user-uploaded images)
- Document manual backup procedure for container data"
```

---

## Task 11: Update Documentation

**Goal:** Document the new wishlist service in current-state.md and create quick reference.

**Files:**
- Modify: `docs/reference/current-state.md`
- Create: `docs/reference/wishlist-quick-reference.md`

### Step 1: Add CT307 to current-state.md container inventory

In `docs/reference/current-state.md`, update the container inventory table:

```markdown
| CTID | Name | IP | Purpose |
|------|------|-----|---------|
| 300 | backup | .120 | Restic backups + Backrest UI |
| 301 | samba | .121 | SMB file shares |
| 302 | ripper | .131 | MakeMKV (optical drive passthrough) |
| 303 | analyzer | .133 | FileBot + media tools |
| 304 | transcoder | .132 | FFmpeg (Intel Arc GPU passthrough) |
| 305 | jellyfin | .130 | Media server (dual GPU passthrough) |
| 307 | wishlist | .186 | Self-hosted gift registry (Node.js) |
| 310 | dns | .110 | Backup DNS (AdGuard Home) |
| 311 | proxy | .111 | Caddy reverse proxy (HTTPS) |
```

### Step 2: Add wishlist to Infrastructure as Code section

In the Ansible roles list, add:

```markdown
- `wishlist` - Self-hosted gift registry application
```

### Step 3: Create wishlist quick reference

```markdown
# Wishlist Quick Reference

**Container:** CT307 (192.168.1.186)
**Access:** https://wishlist.paniland.com (public) or http://192.168.1.186:3280 (local)
**User:** wishlist
**Install Path:** /opt/wishlist

## Common Commands

### Service Management
```bash
# Check status
ssh root@192.168.1.186 "systemctl status wishlist"

# View logs
ssh root@192.168.1.186 "journalctl -u wishlist -f"

# Restart service
ssh root@192.168.1.186 "systemctl restart wishlist"
```

### Application Updates
```bash
# SSH to container
ssh root@192.168.1.186

# Switch to wishlist user
sudo -u wishlist bash

# Navigate to repo
cd /opt/wishlist/repo

# Pull latest changes
git pull origin main

# Install dependencies
pnpm install

# Rebuild application
pnpm build

# Exit back to root
exit

# Restart service
systemctl restart wishlist
```

### Database Management
```bash
# Backup database
ssh root@192.168.1.186 "cp /opt/wishlist/data/prod.db /opt/wishlist/data/prod.db.backup"

# View database size
ssh root@192.168.1.186 "du -sh /opt/wishlist/data/"

# Run Prisma migrations manually
ssh root@192.168.1.186 "sudo -u wishlist bash -c 'cd /opt/wishlist/repo && pnpm prisma migrate deploy'"
```

### Troubleshooting
```bash
# Check if port is listening
ssh root@192.168.1.186 "ss -tlnp | grep 3280"

# Test local connectivity
ssh root@192.168.1.186 "curl -I http://localhost:3280"

# Check Node.js process
ssh root@192.168.1.186 "ps aux | grep node"

# View recent errors
ssh root@192.168.1.186 "journalctl -u wishlist -p err -n 50"
```

## Configuration

**Environment variables:** `/etc/default/wishlist`
**Systemd service:** `/etc/systemd/system/wishlist.service`
**Database:** `/opt/wishlist/data/prod.db` (SQLite)
**Uploads:** `/opt/wishlist/uploads/`

## Infrastructure Management

### Terraform
```bash
cd terraform
terraform plan    # Preview changes
terraform apply   # Apply infrastructure changes
```

### Ansible
```bash
# Full deployment
ansible-playbook ansible/playbooks/wishlist.yml --vault-password-file .vault_pass

# Specific tasks
ansible-playbook ansible/playbooks/wishlist.yml --vault-password-file .vault_pass --tags deploy
ansible-playbook ansible/playbooks/wishlist.yml --vault-password-file .vault_pass --tags systemd
```

## First-Time Setup

1. Navigate to https://wishlist.paniland.com
2. Create admin account
3. Configure default currency and preferences
4. Create wishlists or groups
5. Invite users via email (requires SMTP config) or share registration link

## User Management

Wishlist uses built-in user accounts. User management is done through the web UI.

**Reset user password:** Requires database access (use Prisma Studio or SQL)

```bash
# Option 1: Prisma Studio (recommended)
ssh root@192.168.1.186
sudo -u wishlist bash
cd /opt/wishlist/repo
pnpm prisma studio

# Option 2: Direct SQLite access (advanced)
ssh root@192.168.1.186
sqlite3 /opt/wishlist/data/prod.db
```

## Backup and Restore

### Manual Backup
```bash
ssh root@192.168.1.186 "tar czf /tmp/wishlist-backup.tar.gz /opt/wishlist/data /opt/wishlist/uploads"
scp root@192.168.1.186:/tmp/wishlist-backup.tar.gz ~/backups/wishlist-$(date +%Y%m%d).tar.gz
```

### Restore from Backup
```bash
scp ~/backups/wishlist-20251124.tar.gz root@192.168.1.186:/tmp/
ssh root@192.168.1.186 "systemctl stop wishlist && tar xzf /tmp/wishlist-20251124.tar.gz -C / && systemctl start wishlist"
```

## Security Notes

- Wishlist runs as unprivileged user `wishlist`
- Systemd service has security hardening (NoNewPrivileges, PrivateTmp, ProtectSystem)
- Database and uploads are restricted to wishlist user (755)
- Environment file contains sensitive data (600 permissions)
- HTTPS enforced via Caddy reverse proxy with Cloudflare DNS-01
- Tailscale ACLs restrict access to friends group

## Monitoring

- **Service status:** `systemctl status wishlist`
- **Application logs:** `journalctl -u wishlist -f`
- **Resource usage:** `pct exec 307 -- htop`
- **Disk usage:** `pct exec 307 -- df -h`

## Known Issues

- None yet (new deployment)

---

**Maintenance:** Update this document when configuration or procedures change.
```

### Step 4: Commit documentation updates

```bash
git add docs/reference/current-state.md
git add docs/reference/wishlist-quick-reference.md
git commit -m "docs: add wishlist container to infrastructure documentation

- Update container inventory with CT307
- Add wishlist to Ansible roles list
- Create comprehensive quick reference guide
- Document service management, updates, backups, troubleshooting"
```

---

## Task 12: Verification and Testing

**Goal:** Verify the complete deployment and document first-time setup.

**Files:**
- None (verification only)

### Step 1: Verify container is running

**Command:**
```bash
ssh cuiv@homelab "sudo pct list" | grep 307
```

**Expected output:**
```
307       running       192.168.1.186    wishlist
```

### Step 2: Verify service is active

**Command:**
```bash
ssh root@192.168.1.186 "systemctl is-active wishlist"
```

**Expected output:**
```
active
```

### Step 3: Test local HTTP access

**Command:**
```bash
curl -I http://192.168.1.186:3280
```

**Expected output:** HTTP 200 or 302 with redirect

### Step 4: Test public HTTPS access

**Command:**
```bash
curl -I https://wishlist.paniland.com
```

**Expected output:** HTTP 200 or 302 with valid SSL certificate

### Step 5: Test Tailscale access (if on Tailscale network)

**Command:**
```bash
curl -I http://192.168.1.186:3280
```

**Expected output:** HTTP 200 or 302 (via Tailscale subnet router)

### Step 6: Check application logs for errors

**Command:**
```bash
ssh root@192.168.1.186 "journalctl -u wishlist -n 50 --no-pager"
```

**Expected output:** No critical errors, application started successfully

### Step 7: Verify database was created

**Command:**
```bash
ssh root@192.168.1.186 "ls -lh /opt/wishlist/data/prod.db"
```

**Expected output:** SQLite database file exists

### Step 8: Complete web UI first-time setup

**Manual steps:**
1. Open browser to https://wishlist.paniland.com
2. Create first admin account
3. Set default currency (USD)
4. Create a test wishlist
5. Add a test item
6. Verify item appears in wishlist

### Step 9: Verify Caddy is routing correctly

**Command:**
```bash
ssh root@192.168.1.111 "journalctl -u caddy -n 20 --no-pager" | grep wishlist
```

**Expected output:** Log entries showing successful proxying to wishlist

### Step 10: Document deployment completion

Create a brief summary of deployment status:

```bash
echo "Wishlist deployment completed successfully on $(date)" >> docs/reference/deployment-log.txt
echo "- Container: CT307 (192.168.1.186)" >> docs/reference/deployment-log.txt
echo "- Domain: wishlist.paniland.com" >> docs/reference/deployment-log.txt
echo "- Status: Active and accessible" >> docs/reference/deployment-log.txt
```

---

## Post-Deployment Tasks

### Optional Enhancements

1. **SMTP Configuration** - Configure email sending for invitations
   - Add SMTP variables to `ansible/roles/wishlist/defaults/main.yml`
   - Update `wishlist.env.j2` template with SMTP settings
   - Rerun ansible playbook

2. **OAuth Integration** - Configure OpenID Connect for third-party auth
   - Add OAuth variables to role defaults
   - Update environment template
   - Configure OAuth provider (Google, GitHub, etc.)

3. **Custom Currency** - Change default currency from USD
   - Modify `wishlist_default_currency` variable
   - Rerun ansible playbook

4. **Monitoring** - Add wishlist to monitoring stack (if exists)
   - Configure health check endpoint
   - Add to uptime monitoring

5. **Automated Updates** - Create cron job for git pull + rebuild
   - Add script to `ansible/roles/wishlist/files/`
   - Create cron job or systemd timer

### Maintenance Schedule

- **Weekly:** Check logs for errors
- **Monthly:** Review disk usage (database + uploads)
- **As needed:** Pull updates from upstream repository
- **Before updates:** Backup database

---

## Rollback Procedure

If deployment fails or wishlist is not working:

### Step 1: Stop wishlist service

```bash
ssh root@192.168.1.186 "systemctl stop wishlist"
```

### Step 2: Remove from Caddy

Revert changes to `ansible/playbooks/proxy.yml` and rerun:

```bash
ansible-playbook ansible/playbooks/proxy.yml --vault-password-file .vault_pass --tags caddy
```

### Step 3: Remove from Tailscale ACLs

Revert changes to `terraform/tailscale.tf` and apply:

```bash
cd terraform
terraform apply
```

### Step 4: Destroy container (if needed)

```bash
cd terraform
terraform destroy -target=proxmox_virtual_environment_container.wishlist
```

### Step 5: Revert git commits

```bash
git revert HEAD~N  # N = number of wishlist-related commits
git push
```

---

## Success Criteria

- [ ] Container CT307 created and running
- [ ] Node.js 24 and pnpm installed
- [ ] Wishlist application cloned and built
- [ ] Systemd service active and enabled
- [ ] Local access working (http://192.168.1.186:3280)
- [ ] Public HTTPS access working (https://wishlist.paniland.com)
- [ ] Caddy reverse proxy configured
- [ ] Tailscale ACLs allow friends access
- [ ] Database migrations applied
- [ ] First admin account created
- [ ] Documentation updated
- [ ] Logs show no critical errors

---

## Troubleshooting Guide

### Service won't start

**Check logs:**
```bash
ssh root@192.168.1.186 "journalctl -u wishlist -n 100"
```

**Common issues:**
- Missing Node.js dependencies: Rerun `pnpm install`
- Database migration failed: Manually run `pnpm prisma migrate deploy`
- Port already in use: Check with `ss -tlnp | grep 3280`
- Permission issues: Check ownership of `/opt/wishlist` directories

### Build failures

**Check Node.js version:**
```bash
ssh root@192.168.1.186 "node --version"
```

Must be >= 24.0.0

**Rebuild manually:**
```bash
ssh root@192.168.1.186
sudo -u wishlist bash
cd /opt/wishlist/repo
pnpm install
pnpm prisma generate
pnpm build
```

### HTTPS not working

**Check Caddy logs:**
```bash
ssh root@192.168.1.111 "journalctl -u caddy -f"
```

**Verify DNS:**
```bash
dig wishlist.paniland.com
```

Should resolve to your Caddy proxy IP

**Check Cloudflare API token:**
```bash
ssh root@192.168.1.111 "cat /etc/default/caddy"
```

Verify `CLOUDFLARE_API_TOKEN` is set

### Database issues

**Check database exists:**
```bash
ssh root@192.168.1.186 "ls -lh /opt/wishlist/data/prod.db"
```

**Manually run migrations:**
```bash
ssh root@192.168.1.186
sudo -u wishlist bash
cd /opt/wishlist/repo
export DATABASE_URL="file:/opt/wishlist/data/prod.db"
pnpm prisma migrate deploy
```

**Reset database (DESTRUCTIVE):**
```bash
ssh root@192.168.1.186
systemctl stop wishlist
rm /opt/wishlist/data/prod.db
systemctl start wishlist  # Migrations run on startup
```

---

## Related Skills

- @superpowers:systematic-debugging - For troubleshooting deployment issues
- @superpowers:verification-before-completion - Before marking tasks complete
- @superpowers:test-driven-development - If adding custom features

---

**Plan created:** 2025-11-24
**Estimated time:** 2-3 hours for full deployment
**Complexity:** Medium (involves Terraform, Ansible, Node.js, systemd, reverse proxy)
