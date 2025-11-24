# Adding a New Service to Homelab Infrastructure

**Purpose**: Generic guide for deploying a new web service as an LXC container in the homelab infrastructure using full Infrastructure as Code (Terraform + Ansible).

**Audience**: LLM agents or human operators deploying new services

**Prerequisites**: Terraform and Ansible are configured, SSH keys exist in `ansible/files/ssh-keys/`, vault password is available.

---

## Overview

Adding a new service requires touching 7 key infrastructure components:

1. **IP Allocation** - Assign container ID and IP address
2. **Terraform** - Define LXC container
3. **Ansible Role** - Install and configure the application
4. **Ansible Playbook** - Apply the role to the container
5. **Caddy** - Configure reverse proxy for HTTPS access
6. **DNS** - Add DNS rewrites for domain resolution
7. **Tailscale** - Configure VPN ACLs (if needed)
8. **Documentation** - Update infrastructure state

---

## Step 1: Determine IP Allocation Strategy

**File**: `docs/reference/ip-allocation-strategy.md`

**Task**: Find the appropriate CTID and IP address for your service.

**IP Ranges** (192.168.1.0/24):
- `.100-.104` (5 IPs): Physical hosts
- `.105-.109` (5 IPs): Proxmox tools
- `.110-.119` (10 IPs): Network, DNS & Security
- `.120-.129` (10 IPs): Backup & Storage
- `.130-.149` (20 IPs): Media & *Arr Stack
- `.150-.159` (10 IPs): Monitoring & Analytics
- `.160-.169` (10 IPs): Databases & Dev Tools
- `.170-.179` (10 IPs): IoT & Home Automation
- `.180-.189` (10 IPs): Personal & Productivity
- `.190-.199` (10 IPs): Reserved

**CTID Numbering**:
- 300-309: Backup & Storage
- 310-319: Network, DNS & Security
- 302-305: Media pipeline (legacy exception)
- 306+: Application services in sequence

**Decision Checklist**:
- [ ] Service category identified (e.g., personal productivity, monitoring, media)
- [ ] Next available CTID in sequence determined
- [ ] Next available IP in appropriate range assigned
- [ ] Hostname chosen (usually matches service name)

**Example**:
- Service: Recipe manager (personal productivity)
- Category: Personal & Productivity (.180-.189)
- CTID: 308 (next after 307)
- IP: 192.168.1.187 (next available in range)
- Hostname: recipes

---

## Step 2: Create Terraform Container Definition

**File**: `terraform/<service-name>.tf`

**Task**: Define the LXC container infrastructure.

**Template**:
```hcl
# CT<ID>: <Service Name>
# <Brief description of what this service does>

resource "proxmox_virtual_environment_container" "<service_name>" {
  description = "<Service description>"
  node_name   = "homelab"
  vm_id       = <CTID>

  # Container initialization
  started = true

  # Unprivileged container (use false if GPU/hardware passthrough needed)
  unprivileged = true

  initialization {
    hostname = "<service-name>"

    ip_config {
      ipv4 {
        address = "<IP_ADDRESS>/24"
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
    cores = <NUMBER>  # 2 for most services, 4 for heavy workloads
  }

  memory {
    dedicated = <MB>  # 2048 (2GB) typical, 4096-8192 for heavy apps
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = <GB>  # 20GB typical, more if large local data
  }

  # Mount /mnt/storage from host (OPTIONAL - only if service needs shared storage)
  # mount_point {
  #   volume = "/mnt/storage"
  #   path   = "/mnt/media"  # or appropriate path in container
  # }

  # Features
  features {
    nesting = false  # Set true only if Docker/containers needed inside
  }

  # Tags
  tags = ["<category>", "iac", "<service-name>"]

  # Lifecycle
  lifecycle {
    ignore_changes = [
      initialization[0].user_account,
    ]
  }
}
```

**Apply Terraform**:
```bash
cd terraform
terraform fmt <service-name>.tf
terraform validate
terraform plan
terraform apply
```

**Verify**:
```bash
ssh cuiv@homelab "sudo pct list" | grep <CTID>
```

**Commit**:
```bash
git add terraform/<service-name>.tf
git commit -m "feat: add CT<ID> <service> container terraform definition

- CTID <ID>, IP <IP_ADDRESS> (<Category> range)
- <Privileged/Unprivileged> Debian 12 container
- <X> CPU cores, <Y>GB RAM, <Z>GB disk
- <Brief description of purpose>"
```

---

## Step 3: Create Ansible Role

**Directory**: `ansible/roles/<service-name>/`

### 3.1: Create Role Structure

```bash
mkdir -p ansible/roles/<service-name>/{tasks,templates,defaults,handlers,files}
```

### 3.2: Define Default Variables

**File**: `ansible/roles/<service-name>/defaults/main.yml`

**Template**:
```yaml
---
# Default variables for <service-name> role

# Application
<service>_user: "<service-name>"
<service>_group: "<service-name>"
<service>_home: "/opt/<service-name>"
<service>_port: <PORT>

# Installation (adjust based on deployment method)
# For Node.js apps:
<service>_repo_url: "https://github.com/<user>/<repo>.git"
<service>_repo_version: "main"  # or specific tag

# For Docker apps:
# <service>_docker_image: "ghcr.io/<user>/<image>:latest"

# For binary/package apps:
# <service>_version: "1.2.3"

# Configuration
<service>_data_dir: "{{ <service>_home }}/data"
# Add other service-specific config variables

# Database (if applicable)
# <service>_db_path: "{{ <service>_data_dir }}/database.db"
```

### 3.3: Create Handlers

**File**: `ansible/roles/<service-name>/handlers/main.yml`

**Template**:
```yaml
---
# Handlers for <service-name> role

- name: Restart <service-name>
  ansible.builtin.systemd:
    name: <service-name>
    state: restarted
    daemon_reload: true
  become: true

- name: Reload <service-name>
  ansible.builtin.systemd:
    name: <service-name>
    state: reloaded
  become: true
```

### 3.4: Create Installation Tasks

**File**: `ansible/roles/<service-name>/tasks/install.yml`

**Choose deployment method**:

#### Option A: Native Binary/Package Installation
```yaml
---
# Install <service-name> from package/binary

- name: Install prerequisites
  ansible.builtin.apt:
    name:
      - curl
      - ca-certificates
      # Add other dependencies
    state: present
    update_cache: true
  become: true

- name: Create <service-name> group
  ansible.builtin.group:
    name: "{{ <service>_group }}"
    system: true
  become: true

- name: Create <service-name> user
  ansible.builtin.user:
    name: "{{ <service>_user }}"
    group: "{{ <service>_group }}"
    home: "{{ <service>_home }}"
    shell: /bin/bash
    system: true
    create_home: true
  become: true

# Add download/install tasks specific to your application
```

#### Option B: Docker Container (if using Docker)
```yaml
---
# Install Docker and <service-name> container

- name: Install Docker
  ansible.builtin.apt:
    name:
      - docker.io
      - docker-compose
    state: present
    update_cache: true
  become: true

- name: Create <service-name> user
  ansible.builtin.user:
    name: "{{ <service>_user }}"
    group: docker
    home: "{{ <service>_home }}"
    system: true
    create_home: true
  become: true

- name: Create data directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ <service>_user }}"
    group: "{{ <service>_group }}"
    mode: '0755'
  loop:
    - "{{ <service>_data_dir }}"
  become: true
```

#### Option C: Node.js Application
```yaml
---
# Install Node.js runtime for <service-name>

- name: Install Node.js prerequisites
  ansible.builtin.apt:
    name:
      - ca-certificates
      - curl
      - gnupg
      - git
      - build-essential
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

- name: Install pnpm via npm
  ansible.builtin.command: npm install -g pnpm
  args:
    creates: /usr/bin/pnpm
  become: true

- name: Create <service-name> group
  ansible.builtin.group:
    name: "{{ <service>_group }}"
    system: true
  become: true

- name: Create <service-name> user
  ansible.builtin.user:
    name: "{{ <service>_user }}"
    group: "{{ <service>_group }}"
    home: "{{ <service>_home }}"
    shell: /bin/bash
    system: true
    create_home: true
  become: true

- name: Create data directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ <service>_user }}"
    group: "{{ <service>_group }}"
    mode: '0755'
  loop:
    - "{{ <service>_data_dir }}"
  become: true
```

### 3.5: Create Deployment Tasks (if building from source)

**File**: `ansible/roles/<service-name>/tasks/deploy.yml`

**Template** (adjust based on build system):
```yaml
---
# Deploy <service-name> application

- name: Clone <service-name> repository
  ansible.builtin.git:
    repo: "{{ <service>_repo_url }}"
    dest: "{{ <service>_home }}/repo"
    version: "{{ <service>_repo_version }}"
    force: false
  become: true
  become_user: "{{ <service>_user }}"
  notify: Restart <service-name>

# Add build steps here (e.g., npm install, make, cargo build, etc.)
# Example for Node.js:
# - name: Install dependencies
#   ansible.builtin.command:
#     cmd: pnpm install
#     chdir: "{{ <service>_home }}/repo"
#   become: true
#   become_user: "{{ <service>_user }}"
#   changed_when: true
#   notify: Restart <service-name>
```

### 3.6: Create Systemd Service Configuration

**File**: `ansible/roles/<service-name>/tasks/systemd.yml`

```yaml
---
# Configure <service-name> systemd service

- name: Create <service-name> environment file
  ansible.builtin.template:
    src: <service-name>.env.j2
    dest: /etc/default/<service-name>
    owner: root
    group: root
    mode: '0600'
  become: true
  notify: Restart <service-name>

- name: Create <service-name> systemd service
  ansible.builtin.template:
    src: <service-name>.service.j2
    dest: /etc/systemd/system/<service-name>.service
    owner: root
    group: root
    mode: '0644'
  become: true
  notify: Restart <service-name>

- name: Reload systemd daemon
  ansible.builtin.systemd:
    daemon_reload: true
  become: true

- name: Enable and start <service-name> service
  ansible.builtin.systemd:
    name: <service-name>
    state: started
    enabled: true
  become: true
```

**File**: `ansible/roles/<service-name>/templates/<service-name>.env.j2`

```jinja2
# Environment variables for <service-name> application
# Managed by Ansible - DO NOT EDIT MANUALLY

# Application configuration
PORT={{ <service>_port }}
# Add other environment variables as needed
# DATABASE_URL=...
# API_KEY=...

# Node.js (if applicable)
NODE_ENV=production
```

**File**: `ansible/roles/<service-name>/templates/<service-name>.service.j2`

```jinja2
[Unit]
Description=<Service Display Name>
Documentation=<URL to docs>
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User={{ <service>_user }}
Group={{ <service>_group }}
WorkingDirectory={{ <service>_home }}
EnvironmentFile=/etc/default/<service-name>

# Start application
ExecStart=<command to start application>
# Examples:
# Node.js: /usr/bin/node build
# Python: /usr/bin/python3 app.py
# Binary: {{ <service>_home }}/bin/<service-name>
# Docker: /usr/bin/docker-compose up

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
ReadWritePaths={{ <service>_home }}

# Resource limits
MemoryMax=<X>G
CPUQuota=150%

[Install]
WantedBy=multi-user.target
```

### 3.7: Wire Up Main Tasks

**File**: `ansible/roles/<service-name>/tasks/main.yml`

```yaml
---
# Main tasks for <service-name> role

- name: Import installation tasks
  ansible.builtin.import_tasks: install.yml
  tags: ['<service>', 'install']

- name: Import deployment tasks
  ansible.builtin.import_tasks: deploy.yml
  tags: ['<service>', 'deploy']
  when: <service>_repo_url is defined  # Skip if not building from source

- name: Import systemd tasks
  ansible.builtin.import_tasks: systemd.yml
  tags: ['<service>', 'systemd', 'service']
```

**Commit Role**:
```bash
git add ansible/roles/<service-name>/
git commit -m "feat: create <service-name> ansible role

- Install <brief description of installation>
- Configure application and systemd service
- <Any other key features>"
```

---

## Step 4: Create Ansible Playbook and Inventory

### 4.1: Add to Inventory

**File**: `ansible/inventory/hosts.yml`

**Add to `lxc_containers` children list**:
```yaml
lxc_containers:
  children:
    # ... existing containers ...
    <service>_containers:
```

**Add new container group**:
```yaml
<service>_containers:
  hosts:
    <service-name>:
      ansible_host: <IP_ADDRESS>
      ansible_user: root
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
      container_id: <CTID>
```

### 4.2: Create Playbook

**File**: `ansible/playbooks/<service-name>.yml`

**Template**:
```yaml
---
# Playbook to configure <service-name> container
# Usage: ansible-playbook playbooks/<service-name>.yml --vault-password-file .vault_pass

- name: Configure <service-name> container
  hosts: <service-name>
  become: true

  vars_files:
    - ../vars/<service-name>_secrets.yml  # If secrets needed

  vars:
    # Service-specific overrides (if needed)
    # <service>_port: 8080

  pre_tasks:
    - name: Wait for container to be ready
      ansible.builtin.wait_for_connection:
        timeout: 60

    - name: Gather facts
      ansible.builtin.setup:

  roles:
    - role: common
      vars:
        media_user_enabled: false       # Set true only for media services
        homelab_shell_enabled: true     # Enable zsh for troubleshooting
      tags: ['common', 'base']

    - role: <service-name>
      tags: ['<service>']

  post_tasks:
    - name: Wait for <service-name> service to be active
      ansible.builtin.systemd:
        name: <service-name>
      register: <service>_service
      until: <service>_service.status.ActiveState == "active"
      retries: 5
      delay: 5
      tags: ['verify']

    - name: Check <service-name> is responding
      ansible.builtin.uri:
        url: "http://{{ ansible_host }}:{{ <service>_port }}"
        status_code: 200
      register: <service>_health
      retries: 3
      delay: 5
      until: <service>_health.status == 200
      tags: ['verify']

    - name: Display <service-name> summary
      ansible.builtin.debug:
        msg:
          - "========================================="
          - "CT<CTID> <Service Name> Configuration Complete"
          - "========================================="
          - ""
          - "Container: <service-name> ({{ ansible_host }})"
          - "Local access: http://{{ ansible_host }}:{{ <service>_port }}"
          - "Public domain: https://<service>.paniland.com"
          - ""
          - "Next steps:"
          - "  1. Configure Caddy reverse proxy"
          - "  2. Update Tailscale ACLs (if needed)"
          - "  3. Update DNS rewrites"
          - "  4. Complete first-time setup"
          - ""
          - "Logs: journalctl -u <service-name> -f"
          - "========================================="
      tags: ['verify', 'always']
```

### 4.3: Run Playbook

```bash
cd ansible
ansible-playbook playbooks/<service-name>.yml --vault-password-file ../.vault_pass
```

**Verify Service**:
```bash
curl http://<IP_ADDRESS>:<PORT>
ssh root@<IP_ADDRESS> "systemctl status <service-name>"
```

**Commit**:
```bash
git add ansible/inventory/hosts.yml ansible/playbooks/<service-name>.yml
git commit -m "feat: create <service-name> ansible playbook and inventory

- Add <service-name> container to ansible inventory (CT<CTID>)
- Create playbook with common + <service-name> roles
- Add health checks and verification tasks"
```

---

## Step 5: Configure Caddy Reverse Proxy

**File**: `ansible/playbooks/proxy.yml`

**Task**: Add service to `caddy_proxy_targets` list in the vars section.

**Find the list** (around line 38):
```yaml
caddy_proxy_targets:
  # ... existing services ...
  - domain: "<service>.paniland.com"
    upstream: "<IP_ADDRESS>:<PORT>"
```

**Apply Caddy Configuration**:
```bash
ansible-playbook ansible/playbooks/proxy.yml --vault-password-file .vault_pass --tags caddy
```

**Verify**:
```bash
ssh root@192.168.1.111 "caddy validate --config /etc/caddy/Caddyfile"
```

**Commit**:
```bash
git add ansible/playbooks/proxy.yml
git commit -m "feat: add <service>.paniland.com to Caddy reverse proxy

- Configure reverse proxy for CT<CTID> <service> (<IP>:<PORT>)
- Automatic HTTPS via Cloudflare DNS-01 challenge"
```

---

## Step 6: Configure DNS Rewrites

**File**: `ansible/playbooks/dns.yml`

**Task**: Add DNS rewrites for both `.paniland.com` and `.home.arpa` domains.

### 6.1: Add Service Endpoint (via Proxy)

Find the `SERVICE ENDPOINTS` section (around line 42) and add:
```yaml
- domain: "<service>.paniland.com"
  answer: "192.168.1.111"  # Via Caddy proxy for HTTPS
```

### 6.2: Add Direct Host Access

Find the appropriate container section (e.g., "Personal & productivity containers") and add:
```yaml
- domain: "<service>.home.arpa"
  answer: "<IP_ADDRESS>"
```

### 6.3: Apply DNS Configuration

```bash
ansible-playbook ansible/playbooks/dns.yml --vault-password-file .vault_pass
```

### 6.4: Verify DNS Resolution

```bash
dig @192.168.1.102 <service>.paniland.com +short  # Should return 192.168.1.111
dig @192.168.1.110 <service>.home.arpa +short     # Should return <IP_ADDRESS>
```

**Commit**:
```bash
git add ansible/playbooks/dns.yml
git commit -m "feat: add <service> DNS rewrites to AdGuard Home

- Add <service>.paniland.com → 192.168.1.111 (via Caddy proxy)
- Add <service>.home.arpa → <IP_ADDRESS> (direct container access)"
```

---

## Step 7: Configure Tailscale ACLs (Optional)

**File**: `terraform/tailscale.tf`

**Task**: Add service to Tailscale ACL if friends/external users need VPN access.

**When to skip**: If service is only for admin use or already accessible via proxy.

**Find the ACL section** and add to the friends group destinations:
```hcl
{
  action = "accept"
  src    = ["group:friends"]
  dst    = [
    "192.168.1.130:8096",      # Jellyfin
    "<IP_ADDRESS>:<PORT>",     # <Service Name>
  ]
}
```

**Apply Tailscale Changes**:
```bash
cd terraform
terraform validate
terraform plan
terraform apply
```

**Commit**:
```bash
git add terraform/tailscale.tf
git commit -m "feat: add <service> to Tailscale ACL for friends access

- Allow friends group access to <IP_ADDRESS>:<PORT>
- Enables <service> access over Tailscale VPN"
```

---

## Step 8: Update Documentation

### 8.1: Update Current State

**File**: `docs/reference/current-state.md`

**Add to container inventory table**:
```markdown
| <CTID> | <service> | .<last octet> | <Brief description> |
```

**Add to Ansible roles list**:
```markdown
- `<service-name>` - <Brief description>
```

### 8.2: Create Quick Reference

**File**: `docs/reference/<service-name>-quick-reference.md`

**Template**:
```markdown
# <Service Name> Quick Reference

**Container:** CT<CTID> (<IP_ADDRESS>)
**Access:** https://<service>.paniland.com (public) or http://<IP_ADDRESS>:<PORT> (local)
**User:** <service-name>
**Install Path:** /opt/<service-name>

## Common Commands

### Service Management
\`\`\`bash
# Check status
ssh root@<IP_ADDRESS> "systemctl status <service-name>"

# View logs
ssh root@<IP_ADDRESS> "journalctl -u <service-name> -f"

# Restart service
ssh root@<IP_ADDRESS> "systemctl restart <service-name>"
\`\`\`

### Application Updates
\`\`\`bash
# SSH to container
ssh root@<IP_ADDRESS>

# Switch to service user
sudo -u <service-name> bash

# Update application (adjust based on deployment method)
cd /opt/<service-name>/repo
git pull origin main
# Run build/install steps

# Exit back to root
exit

# Restart service
systemctl restart <service-name>
\`\`\`

### Troubleshooting
\`\`\`bash
# Check if port is listening
ssh root@<IP_ADDRESS> "ss -tlnp | grep <PORT>"

# Test local connectivity
ssh root@<IP_ADDRESS> "curl -I http://localhost:<PORT>"

# View recent errors
ssh root@<IP_ADDRESS> "journalctl -u <service-name> -p err -n 50"
\`\`\`

## Configuration

**Environment variables:** `/etc/default/<service-name>`
**Systemd service:** `/etc/systemd/system/<service-name>.service`
**Data directory:** `/opt/<service-name>/data`

## Infrastructure Management

### Terraform
\`\`\`bash
cd terraform
terraform plan    # Preview changes
terraform apply   # Apply infrastructure changes
\`\`\`

### Ansible
\`\`\`bash
# Full deployment
ansible-playbook ansible/playbooks/<service-name>.yml --vault-password-file .vault_pass

# Specific tasks
ansible-playbook ansible/playbooks/<service-name>.yml --vault-password-file .vault_pass --tags deploy
\`\`\`

## Backup and Restore

### Manual Backup
\`\`\`bash
ssh root@<IP_ADDRESS> "tar czf /tmp/<service>-backup.tar.gz /opt/<service-name>/data"
scp root@<IP_ADDRESS>:/tmp/<service>-backup.tar.gz ~/backups/<service>-$(date +%Y%m%d).tar.gz
\`\`\`

### Restore from Backup
\`\`\`bash
scp ~/backups/<service>-20251124.tar.gz root@<IP_ADDRESS>:/tmp/
ssh root@<IP_ADDRESS> "systemctl stop <service-name> && tar xzf /tmp/<service>-20251124.tar.gz -C / && systemctl start <service-name>"
\`\`\`
```

### 8.3: Commit Documentation

```bash
git add docs/reference/current-state.md docs/reference/<service-name>-quick-reference.md
git commit -m "docs: add <service> container to infrastructure documentation

- Update container inventory with CT<CTID>
- Create comprehensive quick reference guide"
```

---

## Step 9: Final Verification

Run through this checklist to ensure everything is working:

### Infrastructure Verification
```bash
# Container is running
ssh cuiv@homelab "sudo pct list" | grep <CTID>

# Service is active and enabled
ssh root@<IP_ADDRESS> "systemctl is-active <service-name>"
ssh root@<IP_ADDRESS> "systemctl is-enabled <service-name>"
```

### Network Verification
```bash
# Local HTTP access works
curl -I http://<IP_ADDRESS>:<PORT>

# DNS resolves correctly
dig @192.168.1.110 <service>.paniland.com +short  # Should return 192.168.1.111

# HTTPS access works (may need to wait for SSL cert)
curl -I https://<service>.paniland.com
```

### Service Verification
```bash
# No errors in logs
ssh root@<IP_ADDRESS> "journalctl -u <service-name> -n 50 --no-pager"

# Service is responding correctly
curl http://<IP_ADDRESS>:<PORT>  # Should return expected response
```

### Verification Checklist
- [ ] Container created and running
- [ ] Service active and enabled
- [ ] Local access working (http://<IP>:<PORT>)
- [ ] DNS resolving correctly
- [ ] Caddy proxy configured
- [ ] HTTPS access working (https://<service>.paniland.com)
- [ ] Tailscale ACLs updated (if applicable)
- [ ] Logs show no critical errors
- [ ] Documentation updated
- [ ] All changes committed to git

---

## Common Patterns and Decisions

### Container Privileges
- **Unprivileged** (default): Most web services, no hardware access needed
- **Privileged**: GPU passthrough, optical drives, special hardware

### Port Selection
- Avoid: 22 (SSH), 53 (DNS), 80/443 (Caddy), 3000 (AdGuard)
- Common: 3280, 8080, 8096, 8181, 9090, etc.
- Check existing: `grep -r "192.168.1" ansible/playbooks/proxy.yml`

### Resource Allocation Guidelines
- **Light services** (static sites, simple APIs): 1-2 cores, 1-2GB RAM, 10-20GB disk
- **Medium services** (web apps, small databases): 2 cores, 2-4GB RAM, 20-30GB disk
- **Heavy services** (media servers, ML apps): 4+ cores, 4-8GB RAM, 30-50GB disk

### Deployment Methods
1. **Native package** (e.g., nginx, postgresql): Fastest, simplest, best for standard software
2. **Build from source** (e.g., Node.js, Go, Rust apps): Full control, use official repos
3. **Docker** (only if necessary): Adds overhead, prefer native when possible
4. **Pre-built binary**: Good for Go/Rust apps, verify signatures

### Security Considerations
- Always run services as dedicated unprivileged user
- Use systemd security hardening (NoNewPrivileges, ProtectSystem, etc.)
- Set restrictive file permissions (0600 for secrets, 0644 for configs)
- Keep environment files separate from service files
- Use Ansible vault for secrets, never commit plaintext credentials

### Backup Strategy
- **Container disk data**: Manual backup procedures (document in quick-reference)
- **Shared storage** (/mnt/storage): Already backed up by restic
- **Database dumps**: Add to service-specific cron jobs if critical

---

## Troubleshooting Common Issues

### Container won't start
```bash
ssh cuiv@homelab "sudo pct config <CTID>"  # Check config
ssh cuiv@homelab "sudo pct start <CTID>"   # Manual start
```

### Service fails to start
```bash
ssh root@<IP_ADDRESS> "journalctl -u <service-name> -n 100"  # Check logs
ssh root@<IP_ADDRESS> "systemctl status <service-name>"      # Check status
```

### DNS not resolving
```bash
# Test each DNS server
dig @192.168.1.102 <service>.paniland.com +short
dig @192.168.1.110 <service>.paniland.com +short

# Check AdGuard config
ssh root@192.168.1.110 "grep -A 2 '<service>' /opt/AdGuardHome/AdGuardHome.yaml"
```

### Caddy not proxying
```bash
# Check Caddy logs
ssh root@192.168.1.111 "journalctl -u caddy -n 50"

# Verify Caddyfile
ssh root@192.168.1.111 "caddy validate --config /etc/caddy/Caddyfile"

# Check if service is reachable from proxy
ssh root@192.168.1.111 "curl -I http://<IP_ADDRESS>:<PORT>"
```

### Port conflicts
```bash
# Check what's using the port
ssh root@<IP_ADDRESS> "ss -tlnp | grep :<PORT>"
```

---

## Post-Deployment Checklist

After completing all steps, verify:

- [ ] All terraform changes applied successfully
- [ ] All ansible playbooks ran without errors
- [ ] Container is running and accessible via SSH
- [ ] Service is running and responds to HTTP requests
- [ ] DNS resolves correctly for both domains
- [ ] Caddy proxy serves HTTPS correctly
- [ ] Tailscale ACLs allow appropriate access
- [ ] Logs show no errors or warnings
- [ ] Documentation is complete and accurate
- [ ] All changes are committed to git with clear commit messages
- [ ] Service is ready for first-time setup by user

---

## Example: Full Workflow for Adding "Bookmarks" Service

This is a complete example showing all steps for adding a bookmark manager called "linkding":

**Service Details**:
- Name: linkding
- Category: Personal & Productivity
- CTID: 308
- IP: 192.168.1.187
- Port: 9090
- Deployment: Docker container

**Step 1: IP Allocation**
- Range: .180-.189 (Personal & Productivity)
- Next CTID: 308
- Next IP: 192.168.1.187
- Hostname: linkding

**Step 2: Terraform**
```bash
# Create terraform/linkding.tf with CTID 308, IP 192.168.1.187
cd terraform
terraform fmt linkding.tf
terraform validate
terraform plan
terraform apply
git commit -m "feat: add CT308 linkding container"
```

**Step 3: Ansible Role**
```bash
# Create role structure
mkdir -p ansible/roles/linkding/{tasks,templates,defaults,handlers}

# Create defaults/main.yml with linkding_port: 9090, Docker image, etc.
# Create install.yml with Docker installation
# Create systemd.yml with docker-compose service
# Create main.yml importing tasks
git commit -m "feat: create linkding ansible role"
```

**Step 4: Ansible Playbook**
```bash
# Add to inventory: linkding_containers with CT308 at 192.168.1.187
# Create playbooks/linkding.yml
ansible-playbook ansible/playbooks/linkding.yml --vault-password-file .vault_pass
curl http://192.168.1.187:9090  # Verify
git commit -m "feat: create linkding playbook and inventory"
```

**Step 5: Caddy**
```bash
# Add to proxy.yml: linkding.paniland.com → 192.168.1.187:9090
ansible-playbook ansible/playbooks/proxy.yml --vault-password-file .vault_pass --tags caddy
git commit -m "feat: add linkding.paniland.com to Caddy"
```

**Step 6: DNS**
```bash
# Add to dns.yml rewrites:
# linkding.paniland.com → 192.168.1.111
# linkding.home.arpa → 192.168.1.187
ansible-playbook ansible/playbooks/dns.yml --vault-password-file .vault_pass
dig @192.168.1.110 linkding.paniland.com +short  # Verify
git commit -m "feat: add linkding DNS rewrites"
```

**Step 7: Tailscale** (Skip - admin only, no friends access needed)

**Step 8: Documentation**
```bash
# Update current-state.md with CT308
# Create linkding-quick-reference.md
git commit -m "docs: add linkding to infrastructure"
```

**Step 9: Verification**
```bash
# All checks pass
curl https://linkding.paniland.com  # Works!
```

**Result**: 7 commits, fully deployed, fully documented, completely reproducible.

---

## Tips for LLM Agents

1. **Read existing examples**: Look at `terraform/jellyfin.tf`, `ansible/roles/jellyfin/`, `ansible/playbooks/jellyfin.yml` for patterns

2. **Check IP allocation first**: Always consult `docs/reference/ip-allocation-strategy.md` and `docs/reference/current-state.md` before choosing IPs/CTIDs

3. **Use exact patterns**: Copy existing working configurations and modify them rather than creating from scratch

4. **Test incrementally**: Run `terraform plan` before `apply`, use `--check` with ansible, verify each step before proceeding

5. **Follow commit conventions**: Use `feat:`, `fix:`, `docs:` prefixes, write clear descriptions

6. **Don't skip verification**: Always verify service is running and responding before moving to next step

7. **Ask before Docker**: Prefer native installation unless Docker is clearly simpler or required

8. **Read the service docs**: Check upstream documentation for correct ports, environment variables, and dependencies

9. **Security first**: Always create dedicated user, never run as root, use systemd hardening

10. **Document as you go**: Update docs immediately, don't defer to "later"

---

**Last Updated**: 2025-11-24
**Maintainer**: Infrastructure managed via IaC in this repository
