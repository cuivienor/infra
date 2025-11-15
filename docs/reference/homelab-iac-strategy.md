# Homelab Infrastructure as Code Strategy

**Date**: 2025-01-09
**Timeline**: Moderate adoption over 1-2 months
**Goals**: Disaster recovery + Learning + Configuration management
**Scope**: Full automation (containers, software, devices, host config)
**Approach**: Start with new test container, then migrate production

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Technology Stack](#technology-stack)
3. [Project Structure](#project-structure)
4. [Phase 1: Foundation (Week 1-2)](#phase-1-foundation-week-1-2)
5. [Phase 2: First Test Container (Week 3-4)](#phase-2-first-test-container-week-3-4)
6. [Phase 3: Production Migration (Week 5-6)](#phase-3-production-migration-week-5-6)
7. [Phase 4: Host Configuration (Week 7-8)](#phase-4-host-configuration-week-7-8)
8. [Phase 5: Polish & Automation (Ongoing)](#phase-5-polish--automation-ongoing)
9. [Secrets Management](#secrets-management)
10. [Disaster Recovery](#disaster-recovery)
11. [Troubleshooting Guide](#troubleshooting-guide)
12. [Reference Commands](#reference-commands)

---

## Executive Summary

### What We're Building

A complete Infrastructure as Code (IaC) solution for your Proxmox homelab that:
- **Creates containers** via Terraform
- **Configures software** via Ansible
- **Manages device passthrough** (GPU, optical drive)
- **Tracks everything in Git** for version control
- **Enables disaster recovery** - rebuild from scratch
- **Provides learning experience** with industry-standard tools

### Technology Choices

| Tool | Purpose | Why This Tool |
|------|---------|---------------|
| **Terraform** (BPG provider) | Infrastructure provisioning | Industry standard, actively maintained, import existing resources |
| **Ansible** | Configuration management | Idempotent, great for LXC (no cloud-init), mature ecosystem |
| **Ansible Vault** | Secrets management | Built-in encryption, simple for homelab |
| **Git** | Version control | Track changes, rollback capability |
| **Bash** | Orchestration wrappers | Simple deploy/backup scripts |

### Learning Philosophy

This plan emphasizes **understanding over automation**. You'll:
- Build one container from scratch to learn the workflow
- Document everything as you go
- Understand limitations (especially LXC vs VM differences)
- Make mistakes in safe test environment
- Gain transferable professional skills

### Timeline

- **Weeks 1-2**: Install tools, set up Git repo, create API tokens
- **Weeks 3-4**: Build test container from scratch with Terraform + Ansible
- **Weeks 5-6**: Import and migrate ripper + transcoder to IaC
- **Weeks 7-8**: Automate host configuration (MergerFS, GPU drivers)
- **Ongoing**: Refinement, documentation, disaster recovery testing

---

## Technology Stack

### Required Software

**On your workstation (Mac):**
```bash
# Terraform
brew install terraform

# Ansible
brew install ansible

# Ansible collections
ansible-galaxy collection install community.general
```

**Python requirements for Ansible:**
```bash
pip3 install proxmoxer requests
```

**On Proxmox host:**
- API token with appropriate permissions
- SSH key-based authentication configured

### Proxmox Terraform Provider

**Use BPG provider** (actively maintained):
```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}
```

**DO NOT use Telmate provider** (unmaintained, buggy with Proxmox 8+).

### Key Limitations to Accept

1. **LXC doesn't support cloud-init** - Use Ansible for first-boot config
2. **Device passthrough requires Ansible** - Terraform can't set cgroup rules
3. **Some host config stays manual** - Initial Proxmox setup, hardware changes
4. **LXC != VMs** - Different capabilities, different automation approaches

---

## Project Structure

```
~/dev/homelab-iac/
├── terraform/
│   ├── providers.tf           # Provider configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Outputs for Ansible
│   ├── containers/
│   │   ├── test.tf            # Test container
│   │   ├── ripper.tf          # Ripper container
│   │   └── transcoder.tf      # Transcoder container
│   ├── terraform.tfvars       # Your values (git-ignored)
│   └── .gitignore
│
├── ansible/
│   ├── ansible.cfg            # Ansible configuration
│   ├── inventory/
│   │   ├── hosts.yml          # Container inventory
│   │   └── group_vars/
│   │       └── all.yml        # Common variables
│   ├── vars/
│   │   └── secrets.yml        # Ansible Vault (encrypted)
│   ├── roles/
│   │   ├── common/            # Base setup (media user, etc.)
│   │   │   ├── tasks/
│   │   │   │   └── main.yml
│   │   │   └── defaults/
│   │   │       └── main.yml
│   │   ├── gpu_passthrough/   # GPU device configuration
│   │   │   ├── tasks/
│   │   │   └── templates/
│   │   ├── optical_passthrough/ # Optical drive config
│   │   │   └── tasks/
│   │   ├── transcoder/        # FFmpeg, HandBrake
│   │   │   ├── tasks/
│   │   │   └── files/
│   │   └── ripper/            # MakeMKV
│   │       ├── tasks/
│   │       └── files/
│   ├── playbooks/
│   │   ├── site.yml           # Main playbook
│   │   ├── test.yml           # Test container playbook
│   │   └── host.yml           # Proxmox host config
│   └── .gitignore
│
├── scripts/
│   ├── deploy.sh              # Terraform apply + Ansible
│   ├── backup-state.sh        # Backup Terraform state
│   └── destroy-test.sh        # Safely destroy test resources
│
├── docs/
│   ├── setup.md               # Initial setup steps
│   ├── disaster-recovery.md   # DR procedure
│   ├── troubleshooting.md     # Common issues
│   └── decisions.md           # Architecture decisions
│
├── .envrc                     # Environment variables (direnv)
├── .gitignore
├── .vault_pass                # Ansible Vault password (git-ignored)
└── README.md
```

---

## Phase 1: Foundation (Week 1-2)

### Goals
- Set up development environment
- Create Git repository with proper structure
- Establish secrets management
- Generate Proxmox API credentials
- Document current state

### 1.1 Install Tools

```bash
# On your Mac
cd ~/dev/homelab

# Install Terraform
brew install terraform
terraform version

# Install Ansible
brew install ansible
ansible --version

# Install Ansible collections
ansible-galaxy collection install community.general

# Install Python dependencies
pip3 install proxmoxer requests

# Optional: direnv for environment variables
brew install direnv
```

### 1.2 Create Git Repository

```bash
# Create repository
mkdir -p ~/dev/homelab-iac
cd ~/dev/homelab-iac
git init

# Create structure
mkdir -p terraform/containers
mkdir -p ansible/{inventory/group_vars,vars,roles,playbooks}
mkdir -p scripts docs

# Create .gitignore
cat > .gitignore << 'EOF'
# Terraform
terraform/.terraform/
terraform/*.tfstate
terraform/*.tfstate.backup
terraform/.terraform.lock.hcl
terraform/terraform.tfvars
terraform/.terraform.tfstate.lock.info

# Ansible
*.retry
ansible/.vault_pass

# Environment
.envrc
.env

# OS
.DS_Store

# Sensitive
*secret*
*token*
EOF

# Initial commit
git add .
git commit -m "Initial project structure"
```

### 1.3 Set Up Secrets Management

```bash
# Create Ansible Vault password
pwgen 32 1 > ansible/.vault_pass
chmod 600 ansible/.vault_pass

# Configure Ansible to use vault password file
cat > ansible/ansible.cfg << EOF
[defaults]
inventory = inventory/hosts.yml
roles_path = roles
vault_password_file = .vault_pass
host_key_checking = False
retry_files_enabled = False

[ssh_connection]
pipelining = True
EOF
```

### 1.4 Create Proxmox API Token

**On Proxmox web UI:**
1. Navigate to **Datacenter → Permissions → API Tokens**
2. Click **Add**
3. Settings:
   - **User**: root@pam
   - **Token ID**: terraform
   - **Privilege Separation**: Unchecked (full permissions)
4. **Save** and copy the token secret (you can't view it again!)

**Store in Ansible Vault:**
```bash
cd ansible

# Create encrypted secrets file
ansible-vault create vars/secrets.yml
```

Content of `secrets.yml`:
```yaml
---
proxmox_api_url: "https://YOUR_PROXMOX_IP:8006/api2/json"
proxmox_api_token_id: "root@pam!terraform"
proxmox_api_token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Add more secrets as needed
media_user_password: "secure_password_here"
```

**Verify encryption:**
```bash
# Should show encrypted content
cat vars/secrets.yml

# Should show decrypted content
ansible-vault view vars/secrets.yml
```

### 1.5 Document Current State

Create `docs/current-state.md`:

```markdown
# Current Homelab State

**Date**: 2025-01-09

## Proxmox Host
- **Hostname**: proxmox
- **IP**: 192.168.x.x
- **Version**: 8.x
- **Hardware**:
  - Intel Arc GPU: `/dev/dri/card0`, `/dev/dri/renderD128`
  - Optical drive: `/dev/sr0`
  - NVIDIA 1080: `/dev/nvidia*` (if used)

## Storage
- **MergerFS mount**: `/mnt/storage`
  - Source disks: `/mnt/disk1`, `/mnt/disk2`, etc.
  - Options: `allow_other,use_ino,cache.files=off`
- **Media directories**:
  - Staging: `/mnt/storage/media/staging/`
  - Movies: `/mnt/storage/media/movies/`
  - TV: `/mnt/storage/media/tv/`

## Existing Containers
| CTID | Name | Type | Status | Purpose |
|------|------|------|--------|---------|
| XXX | transcoder | Privileged | Running | Blu-ray transcoding |
| XXX | ripper | Privileged | Running | MakeMKV ripping |

## Device Passthrough
- **GPU** (transcoder): card0, renderD128
- **Optical** (ripper): /dev/sr0, /dev/sg0

## Network
- **Bridge**: vmbr0
- **VLAN**: (if applicable)
- **Firewall**: Disabled on containers

## Known Issues
- Write permission issues with unprivileged containers + mergerfs
- Network interface down on first boot (requires manual `dhclient`)

## Manual Configuration
- MergerFS on host
- GPU drivers on host (intel-media-va-driver)
- Media user (UID 1005) - will migrate to 1000
```

### 1.6 Set Up Environment Variables (Optional)

Using `direnv` for cleaner environment:

```bash
# Install direnv
brew install direnv

# Add to your shell (~/.zshrc or ~/.bashrc)
eval "$(direnv hook zsh)"

# Create .envrc in project root
cat > .envrc << 'EOF'
# Terraform variables
export TF_VAR_proxmox_api_url="https://YOUR_PROXMOX_IP:8006/api2/json"
export TF_VAR_proxmox_api_token_id="root@pam!terraform"

# Load token from Ansible Vault (requires ansible-vault)
export TF_VAR_proxmox_api_token_secret="$(ansible-vault view ansible/vars/secrets.yml | grep proxmox_api_token_secret | cut -d: -f2 | xargs)"

# Ansible vault password file
export ANSIBLE_VAULT_PASSWORD_FILE="ansible/.vault_pass"
EOF

# Allow direnv
direnv allow
```

### 1.7 Phase 1 Checklist

- [ ] Terraform installed and working
- [ ] Ansible installed with community.general collection
- [ ] Git repository created with proper structure
- [ ] `.gitignore` configured
- [ ] Ansible Vault password generated and secured
- [ ] Proxmox API token created
- [ ] Secrets stored in encrypted `secrets.yml`
- [ ] Current state documented
- [ ] (Optional) direnv configured for environment variables

### 1.8 Commit Your Work

```bash
git add .
git commit -m "Phase 1: Foundation setup complete

- Created Ansible Vault for secrets
- Documented current homelab state
- Configured Git ignores for sensitive data"
```

---

## Phase 2: First Test Container (Week 3-4)

### Goals
- Create a simple test container from scratch
- Learn Terraform workflow
- Learn Ansible workflow
- Understand integration patterns
- Safe experimentation environment

### 2.1 Create Terraform Provider Configuration

`terraform/providers.tf`:
```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"

  # Allow self-signed certificates (homelab)
  insecure = true

  ssh {
    agent = true
  }
}
```

`terraform/variables.tf`:
```hcl
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "proxmox"  # Adjust to your hostname
}

variable "media_uid" {
  description = "Media user UID"
  type        = number
  default     = 1000
}

variable "media_gid" {
  description = "Media group GID"
  type        = number
  default     = 1000
}
```

`terraform/terraform.tfvars`:
```hcl
# Your specific values
proxmox_api_url         = "https://192.168.x.x:8006/api2/json"
proxmox_api_token_id    = "root@pam!terraform"
proxmox_api_token_secret = "your-token-secret-here"
proxmox_node            = "proxmox"
```

### 2.2 Create Test Container with Terraform

`terraform/containers/test.tf`:
```hcl
resource "proxmox_virtual_environment_container" "test" {
  description = "Test container for IaC workflow"
  node_name   = var.proxmox_node
  vm_id       = 199  # Use high number for test

  started     = true
  unprivileged = false  # Privileged for simplicity

  # Template
  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  # Resources
  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  # Root disk
  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  # Network
  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  # Mount point for storage
  mount_point {
    path   = "/mnt/storage"
    volume = "/mnt/storage"
  }

  initialization {
    hostname = "test-iac"

    dns {
      domain  = "local"
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  features {
    nesting = true
  }
}
```

`terraform/outputs.tf`:
```hcl
output "test_container_id" {
  description = "Test container ID"
  value       = proxmox_virtual_environment_container.test.vm_id
}

output "test_container_ip" {
  description = "Test container IP (manual check)"
  value       = "Check with: pct exec ${proxmox_virtual_environment_container.test.vm_id} ip addr"
}
```

### 2.3 Initialize and Apply Terraform

```bash
cd terraform

# Initialize Terraform (downloads provider)
terraform init

# Validate configuration
terraform validate

# Plan changes (review carefully)
terraform plan

# Apply (create container)
terraform apply

# Note the container ID from output
```

### 2.4 Fix Container Networking

After Terraform creates the container, fix networking:

```bash
# SSH to Proxmox host
ssh root@proxmox

# Get container IP
pct enter 199

# Fix networking
ip link set eth0 up
dhclient eth0
ping -c 3 8.8.8.8

# Make permanent
cat >> /etc/network/interfaces << EOF
auto eth0
iface eth0 inet dhcp
EOF

exit
```

### 2.5 Create Ansible Inventory

`ansible/inventory/hosts.yml`:
```yaml
---
all:
  children:
    test:
      hosts:
        test-iac:
          ansible_host: 192.168.x.x  # Get from pct list or container
          ansible_user: root
          ansible_ssh_private_key_file: ~/.ssh/id_rsa
          container_id: 199
```

Test connectivity:
```bash
cd ansible
ansible test -m ping

# Should return SUCCESS
```

### 2.6 Create Common Role

`ansible/roles/common/defaults/main.yml`:
```yaml
---
media_user: media
media_uid: 1000
media_gid: 1000
media_home: /home/media
```

`ansible/roles/common/tasks/main.yml`:
```yaml
---
- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: 3600

- name: Install common packages
  apt:
    name:
      - vim
      - curl
      - wget
      - htop
      - git
    state: present

- name: Create media group
  group:
    name: "{{ media_user }}"
    gid: "{{ media_gid }}"
    state: present

- name: Create media user
  user:
    name: "{{ media_user }}"
    uid: "{{ media_uid }}"
    group: "{{ media_user }}"
    groups: []
    home: "{{ media_home }}"
    shell: /bin/bash
    create_home: yes
    state: present

- name: Ensure media user home directory permissions
  file:
    path: "{{ media_home }}"
    owner: "{{ media_user }}"
    group: "{{ media_user }}"
    mode: '0755'
    state: directory
```

### 2.7 Create Test Playbook

`ansible/playbooks/test.yml`:
```yaml
---
- name: Configure test container
  hosts: test
  become: yes

  roles:
    - common

  tasks:
    - name: Test storage mount
      stat:
        path: /mnt/storage
      register: storage_mount

    - name: Verify storage is accessible
      assert:
        that:
          - storage_mount.stat.exists
          - storage_mount.stat.isdir
        fail_msg: "Storage mount not accessible"
        success_msg: "Storage mount verified"

    - name: Create test file as media user
      become_user: "{{ media_user }}"
      file:
        path: /mnt/storage/media/staging/iac-test.txt
        state: touch
        mode: '0644'
      register: test_file

    - name: Clean up test file
      file:
        path: /mnt/storage/media/staging/iac-test.txt
        state: absent
      when: test_file is succeeded

    - name: Display success message
      debug:
        msg: "Test container configured successfully!"
```

### 2.8 Run Ansible Playbook

```bash
cd ansible

# Run playbook
ansible-playbook playbooks/test.yml

# Should complete without errors
```

### 2.9 Test Full Workflow

```bash
# Destroy container
cd ~/dev/homelab-iac/terraform
terraform destroy

# Recreate
terraform apply

# Fix networking (manual for now)
ssh root@proxmox "pct exec 199 -- bash -c 'ip link set eth0 up && dhclient eth0'"

# Re-run Ansible
cd ~/dev/homelab-iac/ansible
ansible-playbook playbooks/test.yml

# Verify
ansible test -m shell -a "id media"
ansible test -m shell -a "ls -ld /mnt/storage"
```

### 2.10 Create Deployment Script

`scripts/deploy.sh`:
```bash
#!/bin/bash
set -euo pipefail

echo "=== Homelab IaC Deployment ==="
echo

# Change to project root
cd "$(dirname "$0")/.."

# Terraform
echo "Step 1: Terraform Apply"
cd terraform
terraform apply
echo

# Get container IP (manual for now - will automate later)
echo "Step 2: Verify Container Networking"
echo "Manually check container IP with: pct list"
read -p "Press enter when networking is confirmed..."

# Ansible
echo "Step 3: Ansible Configuration"
cd ../ansible
ansible-playbook playbooks/test.yml
echo

echo "=== Deployment Complete ==="
```

Make executable:
```bash
chmod +x scripts/deploy.sh
```

### 2.11 Phase 2 Checklist

- [ ] Terraform provider configured
- [ ] Test container created with Terraform
- [ ] Container accessible via SSH
- [ ] Ansible inventory created
- [ ] Common role implemented
- [ ] Test playbook runs successfully
- [ ] Storage mount verified
- [ ] Media user created (UID 1000)
- [ ] Full destroy/recreate tested
- [ ] Deployment script created

### 2.12 Commit Your Work

```bash
git add .
git commit -m "Phase 2: First test container complete

- Terraform configuration for LXC containers
- Ansible common role for media user setup
- Test playbook verifying storage access
- Deployment script for automation
- Full destroy/recreate workflow tested"
```

### 2.13 Document Lessons Learned

Create `docs/lessons-learned.md`:

```markdown
# Lessons Learned

## Phase 2: Test Container

### What Worked
- BPG provider is solid and well-documented
- Privileged containers simplify permissions significantly
- Ansible modules are idempotent as promised
- Git workflow prevents mistakes

### Challenges
- Container networking requires manual intervention after creation
- No cloud-init for LXC means Ansible is essential
- Need to wait for container to fully start before Ansible can connect

### Improvements Needed
- Automate network fix (Ansible role?)
- Better wait condition before running Ansible
- Dynamic inventory from Terraform state

### Key Insights
- Terraform manages "what exists"
- Ansible manages "how it's configured"
- Separation of concerns is clear and useful
```

---

## Phase 3: Production Migration (Week 5-6)

### Goals
- Import existing ripper container
- Import existing transcoder container
- Add GPU passthrough via Ansible
- Add optical drive passthrough via Ansible
- Migrate to new media user (UID 1000)

### 3.1 Import Ripper Container

**Document current ripper config:**
```bash
# On Proxmox host
cat /etc/pve/lxc/XXX.conf > ~/ripper-backup-config.txt
pct config XXX
```

**Create Terraform config:**

`terraform/containers/ripper.tf`:
```hcl
resource "proxmox_virtual_environment_container" "ripper" {
  description  = "MakeMKV Blu-ray ripper"
  node_name    = var.proxmox_node
  vm_id        = XXX  # Your actual CT ID

  started      = true
  unprivileged = false

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 4
  }

  memory {
    dedicated = 4096
    swap      = 2048
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  mount_point {
    path   = "/mnt/storage"
    volume = "/mnt/storage"
  }

  initialization {
    hostname = "ripper"

    dns {
      domain  = "local"
      servers = ["8.8.8.8"]
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  features {
    nesting = true
  }

  lifecycle {
    prevent_destroy = true  # Safety: prevent accidental destroy
  }
}
```

**Import into Terraform:**
```bash
cd terraform

# Import existing container
terraform import proxmox_virtual_environment_container.ripper <NODE_NAME>/lxc/<CTID>

# Example:
terraform import proxmox_virtual_environment_container.ripper proxmox/lxc/202

# Plan should show no changes
terraform plan
```

### 3.2 Create Optical Drive Passthrough Role

`ansible/roles/optical_passthrough/tasks/main.yml`:
```yaml
---
- name: Check if container config exists
  stat:
    path: "/etc/pve/lxc/{{ container_id }}.conf"
  delegate_to: "{{ proxmox_host }}"
  register: lxc_config

- name: Add optical drive passthrough to LXC config
  blockinfile:
    path: "/etc/pve/lxc/{{ container_id }}.conf"
    block: |
      lxc.cgroup2.devices.allow: c 11:0 rwm
      lxc.cgroup2.devices.allow: c 21:* rwm
      lxc.mount.entry: /dev/sr0 dev/sr0 none bind,optional,create=file
      lxc.mount.entry: /dev/sg0 dev/sg0 none bind,optional,create=file
      lxc.mount.entry: /dev/sg1 dev/sg1 none bind,optional,create=file
    marker: "# {mark} ANSIBLE MANAGED - OPTICAL DRIVE PASSTHROUGH"
    create: no
  delegate_to: "{{ proxmox_host }}"
  notify: reboot container

- name: Create cdrom group
  group:
    name: cdrom
    gid: 24
    state: present

- name: Add media user to cdrom group
  user:
    name: "{{ media_user }}"
    groups: cdrom
    append: yes
```

`ansible/roles/optical_passthrough/handlers/main.yml`:
```yaml
---
- name: reboot container
  command: "pct reboot {{ container_id }}"
  delegate_to: "{{ proxmox_host }}"
```

### 3.3 Create MakeMKV Role

`ansible/roles/ripper/tasks/main.yml`:
```yaml
---
- name: Install build dependencies
  apt:
    name:
      - build-essential
      - pkg-config
      - libc6-dev
      - libssl-dev
      - libexpat1-dev
      - libavcodec-dev
      - libgl1-mesa-dev
      - qtbase5-dev
      - zlib1g-dev
      - wget
    state: present

- name: Check if MakeMKV is installed
  command: which makemkvcon
  register: makemkv_check
  failed_when: false
  changed_when: false

- name: Download MakeMKV OSS
  get_url:
    url: "https://www.makemkv.com/download/makemkv-oss-{{ makemkv_version }}.tar.gz"
    dest: "/tmp/makemkv-oss-{{ makemkv_version }}.tar.gz"
  when: makemkv_check.rc != 0

- name: Download MakeMKV BIN
  get_url:
    url: "https://www.makemkv.com/download/makemkv-bin-{{ makemkv_version }}.tar.gz"
    dest: "/tmp/makemkv-bin-{{ makemkv_version }}.tar.gz"
  when: makemkv_check.rc != 0

# Build steps (see homelab-media-pipeline-plan.md for complete script)

- name: Create MakeMKV config directory for media user
  file:
    path: /home/{{ media_user }}/.MakeMKV
    owner: "{{ media_user }}"
    group: "{{ media_user }}"
    mode: '0755'
    state: directory

- name: Configure MakeMKV default output
  copy:
    dest: /home/{{ media_user }}/.MakeMKV/settings.conf
    owner: "{{ media_user }}"
    group: "{{ media_user }}"
    mode: '0644'
    content: |
      app_DefaultOutputFileName="{t}"
      app_DestinationDir="/mnt/storage/media/staging"
```

`ansible/roles/ripper/defaults/main.yml`:
```yaml
---
makemkv_version: "1.17.6"  # Check makemkv.com for latest
```

### 3.4 Create Ripper Playbook

`ansible/playbooks/ripper.yml`:
```yaml
---
- name: Configure ripper container
  hosts: ripper
  become: yes

  vars:
    proxmox_host: proxmox  # Your Proxmox hostname

  roles:
    - common
    - ripper

  tasks:
    - name: Verify optical drive access
      stat:
        path: /dev/sr0
      register: optical_drive

    - name: Display optical drive status
      debug:
        msg: "Optical drive {{ 'found' if optical_drive.stat.exists else 'NOT FOUND' }}"

- name: Configure optical drive passthrough (on Proxmox host)
  hosts: ripper
  become: yes

  vars:
    proxmox_host: proxmox
    container_id: "{{ hostvars[inventory_hostname]['container_id'] }}"

  roles:
    - optical_passthrough
```

### 3.5 Update Ansible Inventory

`ansible/inventory/hosts.yml`:
```yaml
---
all:
  children:
    test:
      hosts:
        test-iac:
          ansible_host: 192.168.x.x
          ansible_user: root
          container_id: 199

    ripper:
      hosts:
        ripper:
          ansible_host: 192.168.x.x
          ansible_user: root
          container_id: 202  # Your actual CT ID

    transcoder:
      hosts:
        transcoder:
          ansible_host: 192.168.x.x
          ansible_user: root
          container_id: 201  # Your actual CT ID

all:
  vars:
    proxmox_host: proxmox
    proxmox_host_ip: 192.168.x.x
```

### 3.6 Import and Configure Transcoder

Follow same pattern as ripper:

1. **Document config**: `cat /etc/pve/lxc/XXX.conf`
2. **Create `terraform/containers/transcoder.tf`** (similar to ripper)
3. **Import**: `terraform import ...`
4. **Create GPU passthrough role** (see Phase 4 or existing setup docs)
5. **Create transcoder role** (ffmpeg, HandBrake, GPU drivers)
6. **Create transcoder playbook**
7. **Test**: `ansible-playbook playbooks/transcoder.yml`

### 3.7 Migrate to New Media User (UID 1000)

**On Proxmox host:**
```bash
# Stop containers
pct stop 201
pct stop 202

# Find files owned by old UID (1005)
find /mnt/storage -uid 1005 -ls

# Change ownership (THIS WILL TAKE TIME on large storage)
find /mnt/storage -uid 1005 -exec chown 1000:1000 {} +

# Or use chown -R (faster but less safe)
# chown -R 1000:1000 /mnt/storage

# Start containers
pct start 201
pct start 202
```

**Inside each container (via Ansible):**
```yaml
# Already handled by common role - creates media user with UID 1000
```

### 3.8 Test Production Workflow

```bash
# Deploy all
cd ~/dev/homelab-iac
scripts/deploy.sh

# Test ripper
ssh root@ripper "su - media -c 'makemkvcon info disc:0'"

# Test transcoder
ssh root@transcoder "su - media -c 'vainfo --display drm --device /dev/dri/renderD128'"
ssh root@transcoder "su - media -c 'ffmpeg -hwaccels'"
```

### 3.9 Phase 3 Checklist

- [ ] Ripper container imported into Terraform
- [ ] Transcoder container imported into Terraform
- [ ] `terraform plan` shows no unexpected changes
- [ ] Optical passthrough role created
- [ ] GPU passthrough role created
- [ ] MakeMKV role created and tested
- [ ] Transcoder role created and tested
- [ ] Media user migrated to UID 1000
- [ ] Storage ownership updated
- [ ] All workflows tested and working

### 3.10 Commit Your Work

```bash
git add .
git commit -m "Phase 3: Production containers migrated to IaC

- Imported ripper and transcoder containers
- Created device passthrough roles (GPU, optical)
- Created application roles (MakeMKV, transcoding tools)
- Migrated to unified media user (UID 1000)
- Tested full ripping and transcoding workflows"
```

---

## Phase 4: Host Configuration (Week 7-8)

### Goals
- Automate Proxmox host configuration
- MergerFS setup
- GPU driver installation
- UDEV rules for device permissions
- System-level dependencies

**⚠️ WARNING**: This phase modifies the Proxmox host. Test carefully, have backups.

### 4.1 Create Host Inventory

`ansible/inventory/hosts.yml` (update):
```yaml
all:
  children:
    proxmox_hosts:
      hosts:
        proxmox:
          ansible_host: 192.168.x.x
          ansible_user: root

    # ... existing containers ...
```

### 4.2 Create Host Configuration Role

`ansible/roles/proxmox_host/tasks/main.yml`:
```yaml
---
- name: Install Intel GPU drivers
  apt:
    name:
      - intel-media-va-driver
      - va-driver-all
      - intel-gpu-tools
    state: present

- name: Install MergerFS
  apt:
    name: mergerfs
    state: present

- name: Create mount points for disks
  file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  loop:
    - /mnt/disk1
    - /mnt/disk2
    - /mnt/disk3
    - /mnt/storage

- name: Configure MergerFS in fstab
  mount:
    path: /mnt/storage
    src: "/mnt/disk1:/mnt/disk2:/mnt/disk3"
    fstype: fuse.mergerfs
    opts: "defaults,nonempty,allow_other,use_ino,cache.files=off,moveonenospc=true,category.create=mfs,minfreespace=250G"
    state: mounted

- name: Create media user on host
  user:
    name: media
    uid: 1000
    group: media
    groups: video,render,cdrom
    append: yes

- name: Set storage ownership
  file:
    path: /mnt/storage
    owner: media
    group: media
    recurse: yes
  async: 7200  # 2 hours timeout for large storage
  poll: 0

- name: Create UDEV rule for GPU permissions
  copy:
    dest: /etc/udev/rules.d/99-gpu-permissions.rules
    content: |
      SUBSYSTEM=="drm", KERNEL=="card*", MODE="0660", GROUP="video"
      SUBSYSTEM=="drm", KERNEL=="renderD*", MODE="0660", GROUP="render"
    mode: '0644'
  notify: reload udev

- name: Create UDEV rule for optical drive
  copy:
    dest: /etc/udev/rules.d/99-optical-permissions.rules
    content: |
      SUBSYSTEM=="block", KERNEL=="sr*", GROUP="cdrom", MODE="0660"
      SUBSYSTEM=="scsi_generic", KERNEL=="sg*", GROUP="cdrom", MODE="0660"
    mode: '0644'
  notify: reload udev
```

`ansible/roles/proxmox_host/handlers/main.yml`:
```yaml
---
- name: reload udev
  command: udevadm control --reload-rules && udevadm trigger
```

### 4.3 Create Host Playbook

`ansible/playbooks/host.yml`:
```yaml
---
- name: Configure Proxmox host
  hosts: proxmox_hosts
  become: yes

  pre_tasks:
    - name: Confirm host configuration
      pause:
        prompt: |
          ⚠️  WARNING: This will modify your Proxmox host configuration.

          Changes include:
          - Install GPU drivers
          - Configure MergerFS
          - Create media user (UID 1000)
          - Set storage ownership (may take hours)
          - Create UDEV rules

          Type 'yes' to continue
      register: confirm

    - name: Abort if not confirmed
      fail:
        msg: "Host configuration aborted by user"
      when: confirm.user_input != 'yes'

  roles:
    - proxmox_host

  post_tasks:
    - name: Display completion message
      debug:
        msg: |
          Host configuration complete!

          Next steps:
          1. Reboot Proxmox host to ensure all changes take effect
          2. Verify MergerFS mount: df -h /mnt/storage
          3. Verify GPU drivers: vainfo --display drm --device /dev/dri/renderD128
          4. Check storage ownership: ls -ld /mnt/storage
```

### 4.4 Test Host Configuration

```bash
# Dry run first
ansible-playbook playbooks/host.yml --check

# Review what would change
ansible-playbook playbooks/host.yml --check --diff

# Apply (will prompt for confirmation)
ansible-playbook playbooks/host.yml

# Monitor async task (storage ownership)
ansible proxmox_hosts -m async_status -a "jid=<JOB_ID>"
```

### 4.5 Verify Host Configuration

```bash
# SSH to Proxmox
ssh root@proxmox

# Check MergerFS
df -h /mnt/storage
mount | grep mergerfs

# Check GPU drivers
vainfo --display drm --device /dev/dri/renderD128

# Check media user
id media

# Check storage ownership (sample)
ls -ld /mnt/storage/media
```

### 4.6 Phase 4 Checklist

- [ ] Host configuration role created
- [ ] Dry run completed without errors
- [ ] Host playbook executed successfully
- [ ] MergerFS mounted and functional
- [ ] GPU drivers installed and working
- [ ] Media user created on host (UID 1000)
- [ ] Storage ownership updated (async task completed)
- [ ] UDEV rules applied
- [ ] Host rebooted and verified

### 4.7 Commit Your Work

```bash
git add .
git commit -m "Phase 4: Proxmox host configuration automated

- Created proxmox_host role for system configuration
- Automated MergerFS setup and mounting
- Installed GPU drivers on host
- Created UDEV rules for device permissions
- Configured media user on host with hardware groups"
```

---

## Phase 5: Polish & Automation (Ongoing)

### Goals
- Improve deployment workflow
- Add health checks
- Create backup automation
- Document disaster recovery
- Continuous improvement

### 5.1 Enhanced Deployment Script

`scripts/deploy.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Change to project root
cd "$(dirname "$0")/.."

log "=== Homelab IaC Deployment ==="
echo

# Pre-flight checks
log "Pre-flight checks..."
command -v terraform >/dev/null 2>&1 || error "Terraform not installed"
command -v ansible >/dev/null 2>&1 || error "Ansible not installed"
[[ -f terraform/terraform.tfvars ]] || error "terraform.tfvars not found"
[[ -f ansible/.vault_pass ]] || error "Ansible vault password not found"
log "Pre-flight checks passed"
echo

# Terraform
log "Step 1: Terraform Plan"
cd terraform
terraform plan -out=tfplan
echo

read -p "Apply Terraform plan? (yes/no): " apply_tf
if [[ "$apply_tf" == "yes" ]]; then
  log "Applying Terraform..."
  terraform apply tfplan
  rm tfplan
else
  warn "Skipping Terraform apply"
fi
echo

# Ansible
log "Step 2: Ansible Playbook"
cd ../ansible

log "Running site playbook..."
ansible-playbook playbooks/site.yml

echo
log "=== Deployment Complete ==="
```

### 5.2 Create Site Playbook

`ansible/playbooks/site.yml`:
```yaml
---
- name: Deploy homelab infrastructure
  import_playbook: host.yml
  tags: ['host']

- name: Configure ripper container
  import_playbook: ripper.yml
  tags: ['ripper', 'containers']

- name: Configure transcoder container
  import_playbook: transcoder.yml
  tags: ['transcoder', 'containers']

- name: Health checks
  hosts: all
  become: yes
  tags: ['health']

  tasks:
    - name: Check disk space
      shell: df -h /mnt/storage | tail -1 | awk '{print $5}' | sed 's/%//'
      register: disk_usage
      changed_when: false

    - name: Warn if disk > 90% full
      debug:
        msg: "⚠️  WARNING: Storage is {{ disk_usage.stdout }}% full"
      when: disk_usage.stdout|int > 90

    - name: Check media user exists
      getent:
        database: passwd
        key: media
      failed_when: false

    - name: Verify storage mount
      stat:
        path: /mnt/storage
      register: storage
      failed_when: not storage.stat.exists or not storage.stat.isdir
```

### 5.3 Backup Script

`scripts/backup-state.sh`:
```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR=~/homelab-iac-backups
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

echo "Backing up Terraform state..."
cp terraform/terraform.tfstate "$BACKUP_DIR/terraform-$DATE.tfstate"

echo "Backing up Ansible vault (encrypted)..."
cp ansible/vars/secrets.yml "$BACKUP_DIR/secrets-$DATE.yml"

echo "Creating Git bundle..."
git bundle create "$BACKUP_DIR/repo-$DATE.bundle" --all

# Keep only last 10 backups
cd "$BACKUP_DIR"
ls -t terraform-*.tfstate | tail -n +11 | xargs -r rm
ls -t secrets-*.yml | tail -n +11 | xargs -r rm
ls -t repo-*.bundle | tail -n +11 | xargs -r rm

echo "Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
```

Make executable:
```bash
chmod +x scripts/backup-state.sh
```

### 5.4 Disaster Recovery Documentation

Create `docs/disaster-recovery.md`:

```markdown
# Disaster Recovery Procedure

## Scenario: Complete Hardware Failure

### Prerequisites
- Fresh Proxmox installation on new hardware
- Backup of Terraform state
- Backup of Ansible vault
- Git repository (GitHub/GitLab or local bundle)
- Data backups (MergerFS content)

### Recovery Steps

#### 1. Restore Git Repository
```bash
# From GitHub/GitLab
git clone https://github.com/yourusername/homelab-iac.git
cd homelab-iac

# Or from bundle
git clone ~/backups/repo-YYYYMMDD.bundle homelab-iac
cd homelab-iac
```

#### 2. Restore Secrets
```bash
cp ~/backups/secrets-YYYYMMDD.yml ansible/vars/secrets.yml
cp ~/backups/terraform-YYYYMMDD.tfstate terraform/terraform.tfstate
```

#### 3. Configure New Proxmox Host
```bash
# Update IP in terraform.tfvars
# Update IP in ansible/inventory/hosts.yml

# Create API token on new Proxmox
# Update secrets.yml with new token
ansible-vault edit ansible/vars/secrets.yml
```

#### 4. Apply Infrastructure
```bash
# Host configuration
ansible-playbook ansible/playbooks/host.yml

# Reboot host
ssh root@proxmox reboot

# Wait for boot, then apply Terraform
cd terraform
terraform init
terraform apply

# Configure containers
cd ../ansible
ansible-playbook playbooks/site.yml
```

#### 5. Restore Data
```bash
# Restore MergerFS backing disks
# rsync, Borg, or whatever backup solution you use

# Verify ownership
ssh root@proxmox "ls -ld /mnt/storage/media"
# Should be media:media (1000:1000)
```

#### 6. Verify Services
```bash
# Test ripper
ssh root@ripper "su - media -c 'makemkvcon info disc:0'"

# Test transcoder
ssh root@transcoder "su - media -c 'ffmpeg -hwaccels'"
```

### Recovery Time Objective (RTO)
- Hardware procurement: Hours to days (depends on availability)
- Fresh Proxmox install: 30 minutes
- Infrastructure code apply: 15 minutes
- Data restoration: Hours to days (depends on backup size)
- **Total: 1-3 days with data, <1 hour without data**

### Testing
Run disaster recovery test annually on spare hardware or VM.
```

### 5.5 Troubleshooting Guide

Create `docs/troubleshooting.md`:

```markdown
# Troubleshooting Guide

## Terraform Issues

### Issue: "Resource already exists"
**Cause:** Trying to create resource that already exists

**Solution:**
```bash
# Import existing resource
terraform import proxmox_virtual_environment_container.name node/lxc/ID

# Or remove from Terraform
terraform state rm proxmox_virtual_environment_container.name
```

### Issue: "API token unauthorized"
**Cause:** Token expired or wrong permissions

**Solution:**
```bash
# Recreate API token in Proxmox UI
# Update ansible/vars/secrets.yml
ansible-vault edit ansible/vars/secrets.yml
```

## Ansible Issues

### Issue: "Host unreachable"
**Cause:** Container networking not configured

**Solution:**
```bash
# Fix networking
ssh root@proxmox "pct exec <CTID> -- bash -c 'ip link set eth0 up && dhclient eth0'"

# Or enter container manually
pct enter <CTID>
ip link set eth0 up
dhclient eth0
```

### Issue: "Permission denied" in playbook
**Cause:** Wrong SSH key or user

**Solution:**
```bash
# Test connectivity
ansible <host> -m ping

# Check inventory
cat ansible/inventory/hosts.yml

# Try with password auth
ansible <host> -m ping --ask-pass
```

## Container Issues

### Issue: GPU not accessible
**Cause:** Device passthrough not configured

**Solution:**
```bash
# Verify devices exist in container
pct enter <CTID>
ls -l /dev/dri/

# If missing, check LXC config on host
cat /etc/pve/lxc/<CTID>.conf | grep -A5 "ANSIBLE MANAGED"

# Re-run Ansible
ansible-playbook playbooks/transcoder.yml --tags gpu
```

### Issue: Storage not writable
**Cause:** Wrong ownership or permissions

**Solution:**
```bash
# On Proxmox host
chown -R media:media /mnt/storage
chmod -R g+w /mnt/storage

# In container
id media  # Should be UID 1000
ls -ld /mnt/storage  # Should show media:media
```

## MergerFS Issues

### Issue: Mount point empty
**Cause:** MergerFS not mounted

**Solution:**
```bash
# Check mount
df -h /mnt/storage

# Remount
mount -a

# Check fstab
cat /etc/fstab | grep mergerfs
```
```

### 5.6 Monitoring and Alerts (Optional)

Future enhancements:
- Prometheus metrics from containers
- Grafana dashboards for GPU usage, disk space
- Email alerts on errors
- Integration with Uptime Kuma or similar

### 5.7 Phase 5 Checklist

- [ ] Enhanced deployment script with health checks
- [ ] Site playbook for full deployment
- [ ] Backup automation script
- [ ] Disaster recovery documentation
- [ ] Troubleshooting guide
- [ ] Scheduled backup cron job
- [ ] DR test completed (optional)

---

## Secrets Management

### Ansible Vault

**Create encrypted file:**
```bash
ansible-vault create vars/secrets.yml
```

**Edit encrypted file:**
```bash
ansible-vault edit vars/secrets.yml
```

**View encrypted file:**
```bash
ansible-vault view vars/secrets.yml
```

**Rekey (change password):**
```bash
ansible-vault rekey vars/secrets.yml
```

### Vault Password Management

**Store in file (gitignored):**
```bash
echo "your-vault-password" > ansible/.vault_pass
chmod 600 ansible/.vault_pass
```

**Reference in ansible.cfg:**
```ini
[defaults]
vault_password_file = .vault_pass
```

**Use environment variable:**
```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible_vault_pass
```

### What to Encrypt

**Always encrypt:**
- Proxmox API tokens
- User passwords
- SSH private keys (if stored in repo)
- API keys for external services

**Don't encrypt:**
- Usernames
- Hostnames
- Non-sensitive configuration

### Example Secrets File

```yaml
---
# Proxmox
proxmox_api_url: "https://192.168.1.100:8006/api2/json"
proxmox_api_token_id: "root@pam!terraform"
proxmox_api_token_secret: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Users
media_user_password: "{{ lookup('password', '/dev/null length=32') }}"
root_password: "your-secure-password"

# External Services (if applicable)
plex_claim_token: "claim-xxxxxxxxxxxxx"
```

---

## Disaster Recovery

### Backup Strategy

**What to backup:**
1. **Terraform state** - `terraform/terraform.tfstate`
2. **Ansible vault** - `ansible/vars/secrets.yml`
3. **Git repository** - All IaC code
4. **Proxmox container backups** - Via Proxmox built-in backup
5. **MergerFS data** - Your actual media files

**Backup frequency:**
- Terraform state: After every apply
- Git: Every commit (push to remote)
- Ansible vault: After changes
- Containers: Weekly (Proxmox job)
- Data: Daily/weekly (rsync, Borg, etc.)

**Backup locations:**
- **Primary**: Local NAS or external drive
- **Secondary**: Cloud storage (encrypted)
- **Tertiary**: Git remote (code only)

### Automated Backups

**Cron job for state backups:**
```bash
# Add to crontab
crontab -e

# Backup Terraform state daily at 2 AM
0 2 * * * /home/user/dev/homelab-iac/scripts/backup-state.sh
```

### Restoration Testing

**Annual DR drill:**
1. Create VM or use spare hardware
2. Install fresh Proxmox
3. Restore from backups
4. Document time and issues
5. Update procedures

---

## Troubleshooting Guide

### Common Issues

#### Terraform `terrаform plan` Shows Unexpected Changes

**Cause:** Manual changes made outside Terraform

**Solution:**
```bash
# Review what changed
terraform plan -detailed-exitcode

# Option 1: Import manual changes
terraform import <resource> <id>

# Option 2: Revert manual changes
terraform apply

# Option 3: Update Terraform to match (last resort)
# Edit .tf files to reflect current state
```

#### Ansible Playbook Fails with "Unreachable"

**Cause:** Container networking issue or SSH problem

**Solution:**
```bash
# Test connectivity
ansible <host> -m ping

# Check container is running
pct status <CTID>

# Fix networking manually
pct enter <CTID>
ip link set eth0 up
dhclient eth0

# Verify SSH
ssh root@<container-ip> echo "Connected"
```

#### Device Passthrough Not Working

**Cause:** LXC config not updated or container not rebooted

**Solution:**
```bash
# Check LXC config
cat /etc/pve/lxc/<CTID>.conf | grep lxc.cgroup

# Reboot container
pct reboot <CTID>

# Verify devices in container
pct enter <CTID>
ls -l /dev/dri/  # GPU
ls -l /dev/sr0   # Optical
```

#### Storage Permission Denied

**Cause:** UID mismatch or missing permissions

**Solution:**
```bash
# Check ownership on host
ls -ld /mnt/storage

# Check user in container
id media

# Fix ownership on host
chown -R media:media /mnt/storage
chmod -R g+w /mnt/storage
```

---

## Reference Commands

### Terraform

```bash
# Initialize
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy resources
terraform destroy

# Import existing resource
terraform import <resource.name> <node>/lxc/<id>

# Show state
terraform show

# List resources
terraform state list

# Remove from state
terraform state rm <resource.name>
```

### Ansible

```bash
# Ping hosts
ansible all -m ping

# Run playbook
ansible-playbook playbooks/site.yml

# Run with tags
ansible-playbook playbooks/site.yml --tags containers

# Dry run
ansible-playbook playbooks/site.yml --check

# Show differences
ansible-playbook playbooks/site.yml --diff

# Run single task
ansible <host> -m shell -a "command"

# View encrypted file
ansible-vault view vars/secrets.yml

# Edit encrypted file
ansible-vault edit vars/secrets.yml
```

### Proxmox

```bash
# List containers
pct list

# Container status
pct status <CTID>

# Start container
pct start <CTID>

# Stop container
pct stop <CTID>

# Reboot container
pct reboot <CTID>

# Enter container
pct enter <CTID>

# Execute command in container
pct exec <CTID> -- command

# Show container config
pct config <CTID>

# Backup container
vzdump <CTID> --storage local
```

### Git

```bash
# Status
git status

# Add files
git add .

# Commit
git commit -m "message"

# Push to remote
git push origin main

# View history
git log --oneline

# Create branch
git checkout -b feature/new-thing

# View differences
git diff
```

---

## Next Steps After Completion

### Short Term
1. Run full backup of Terraform state
2. Push Git repository to remote (GitHub/GitLab)
3. Document any custom modifications
4. Schedule regular state backups

### Medium Term
1. Add more containers (media server, *arr stack)
2. Implement monitoring (Prometheus/Grafana)
3. Set up automated testing (test containers)
4. Create CI/CD pipeline (optional)

### Long Term
1. Expand to multi-node Proxmox cluster
2. Add Kubernetes layer (if desired)
3. Implement advanced networking (VLANs, firewall rules)
4. Full GitOps workflow with ArgoCD/Flux

---

## Additional Resources

### Documentation
- **Terraform BPG Provider**: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
- **Ansible Proxmox Modules**: https://docs.ansible.com/ansible/latest/collections/community/general/proxmox_module.html
- **Proxmox LXC**: https://pve.proxmox.com/wiki/Linux_Container

### Community
- **r/homelab**: https://reddit.com/r/homelab
- **r/proxmox**: https://reddit.com/r/proxmox
- **Proxmox Forum**: https://forum.proxmox.com/

### Example Repositories
- **pezhore/Proxmox-Home-Lab**: Multi-node with Terraform + Packer
- **stevius10/Proxmox-GitOps**: Self-configuring LXC automation

---

**End of IaC Strategy Document**

This living document should be updated as you learn and refine your approach. Good luck!
