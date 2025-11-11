# Samba Container Implementation Plan

**Created**: 2025-01-11
**Status**: Ready for implementation

---

## Overview

Deploy a privileged Debian 12 LXC container (CT301) running Samba to provide SMB file sharing for `/mnt/storage`. Configuration optimized for large file streaming (movie playback during media pipeline organization).

### Goals
- ✅ Simple SMB access to `/mnt/storage` from any client (Windows/macOS/Linux)
- ✅ Password authentication (media user)
- ✅ Large file streaming performance
- ✅ Follows existing IaC patterns (Terraform + Ansible)
- ✅ No over-engineering (no service discovery, no workgroup config)

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Proxmox Host (homelab - 192.168.1.56)             │
│                                                     │
│  /mnt/storage (35TB MergerFS)                       │
│  ├── media/                                         │
│  │   ├── library/       (organized media)          │
│  │   ├── movies/                                   │
│  │   └── tv/                                       │
│  └── staging/           (pipeline work area)       │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │ CT301: Samba File Server                      │  │
│  │ - Debian 12 (privileged)                      │  │
│  │ - 1 core, 1GB RAM, 8GB disk                   │  │
│  │ - Mount: /mnt/storage (read-write)            │  │
│  │                                               │  │
│  │ Services:                                     │  │
│  │ - smbd (SMB daemon)                           │  │
│  │ - nmbd (NetBIOS name service)                 │  │
│  │                                               │  │
│  │ Share: [storage]                              │  │
│  │ - Path: /mnt/storage                          │  │
│  │ - User: media (UID 1000)                      │  │
│  │ - Protocol: SMB2/SMB3 only                    │  │
│  │ - Optimized: Large file transfers             │  │
│  └───────────────────────────────────────────────┘  │
│               │                                     │
└───────────────┼─────────────────────────────────────┘
                │
                ▼
        ┌───────────────┐
        │  LAN Clients  │
        │               │
        │  - macOS      │
        │  - Windows    │
        │  - Linux      │
        └───────────────┘
    Access: \\CT301_IP\storage
    User: media / password
```

---

## Container Specification

```yaml
Container ID: 301
Name: samba
Purpose: SMB file server for /mnt/storage access
OS: Debian 12 (bookworm)

Resources:
  CPU: 1 core
  RAM: 1GB
  Disk: 8GB
  Swap: 512MB

Network:
  Bridge: vmbr0
  IP: DHCP assigned

Storage:
  Mount: /mnt/storage → /mnt/storage
  Access: Read-write

Privileges: Privileged (required for mount point)

Tags: infrastructure, file-sharing, samba
```

---

## Authentication Design

### Single Shared User Model

**User**: `media` (UID 1000)
**Password**: Stored in Ansible Vault (`vars/secrets.yml`)
**Access**: Password required, no guest access

### Why This Approach?

✅ **Simple**: One credential to manage
✅ **Consistent**: Matches existing media user (UID 1000) across infrastructure
✅ **Secure enough**: Password-based auth on LAN-only network
✅ **Convenient**: OS credential managers remember password after first use
✅ **Maintainable**: Single user to audit and rotate

### Client Behavior

**First access**: Prompt for credentials
- Username: `media`
- Password: (from Ansible Vault)

**Subsequent access**: Credentials cached by OS
- macOS: Keychain
- Windows: Credential Manager
- Linux: GNOME Keyring / KWallet

---

## Share Configuration

### Single Share: `[storage]`

```smb.conf
[storage]
  path = /mnt/storage
  comment = Homelab Storage Pool (MergerFS)
  browseable = yes
  writable = yes
  valid users = media
  force user = media
  force group = media
  create mask = 0664
  directory mask = 0775
```

**Permissions**:
- Files: 0664 (rw-rw-r--)
- Directories: 0775 (rwxrwxr-x)
- Ownership: media:media (UID/GID 1000)

**Features**:
- Full read/write access
- Consistent ownership (all files owned by media)
- Matches existing storage permissions

---

## Performance Optimization

### Large File Streaming

Configuration tuned for movie file playback:

```ini
# Socket buffers for large transfers
socket options = SO_RCVBUF=524288 SO_SNDBUF=524288

# Enable efficient I/O
use sendfile = yes
read raw = yes
write raw = yes
max xmit = 65536
aio read size = 16384
aio write size = 16384
```

**Expected behavior**:
- Stream 4K movies without buffering
- Responsive seeking (forward/backward)
- Low CPU usage on container
- No need to download entire file

### MergerFS Compatibility

```ini
# Required for MergerFS symlink traversal
unix extensions = no
allow insecure wide links = yes
wide links = yes
follow symlinks = yes
```

MergerFS may use symlinks for file distribution across disks. This configuration allows Samba to follow them transparently.

---

## Implementation Steps

### Prerequisites

- [ ] Proxmox host accessible at 192.168.1.56
- [ ] /mnt/storage mounted and accessible
- [ ] Terraform configured with Proxmox provider
- [ ] Ansible configured with Vault password
- [ ] Debian 12 LXC template available

**Check template**:
```bash
ssh root@192.168.1.56 "pveam list local | grep debian-12"
```

If missing:
```bash
ssh root@192.168.1.56 "pveam download local debian-12-standard_12.7-1_amd64.tar.zst"
```

---

### Part 1: Terraform (Container Provisioning)

#### Task 1.1: Create Container Definition

**File**: `terraform/containers/ct301-samba.tf`

**Content**: See full Terraform configuration in appendix.

**Key configuration**:
- VMID: 301
- Privileged container (unprivileged = false)
- Mount: /mnt/storage (read-write)
- Network: vmbr0 bridge, DHCP
- Tags: infrastructure, file-sharing, samba

#### Task 1.2: Apply Terraform

```bash
cd terraform
terraform plan
# Review: Should show 1 resource to add

terraform apply
# Type 'yes' to confirm

# Note the IP address from output
terraform output ct301_samba_ip
# Export for Ansible
export CT301_IP=$(terraform output -raw ct301_samba_ip | cut -d'/' -f1)
```

**Verify**:
```bash
ssh root@192.168.1.56 "pct list | grep 301"
ssh root@192.168.1.56 "pct config 301 | grep mp0"
ssh root@$CT301_IP "ls -ld /mnt/storage"
```

---

### Part 2: Ansible (Samba Configuration)

#### Task 2.1: Create Role Structure

```bash
cd ansible
mkdir -p roles/samba/{tasks,templates,handlers,vars}
```

#### Task 2.2: Create Ansible Files

**Files to create**:
1. `roles/samba/tasks/main.yml` - Installation and configuration tasks
2. `roles/samba/templates/smb.conf.j2` - Samba configuration template
3. `roles/samba/handlers/main.yml` - Service restart handlers
4. `playbooks/ct301-samba.yml` - Main playbook

**Full content**: See appendix for complete file contents.

#### Task 2.3: Add Samba Password to Vault

```bash
cd ansible
ansible-vault edit vars/secrets.yml
```

Add:
```yaml
# Samba media user password
samba_media_password: "<GENERATE_STRONG_PASSWORD>"
```

**Generate password**:
```bash
openssl rand -base64 18
```

Requirements: 12+ characters, mixed case, numbers, symbols

#### Task 2.4: Update Inventory

**File**: `ansible/inventory/hosts.yml`

Add under `infrastructure` group:
```yaml
ct301_samba:
  ansible_host: "{{ lookup('env', 'CT301_IP') | default('192.168.1.XXX', true) }}"
  ansible_user: root
  container_id: 301
  ansible_python_interpreter: /usr/bin/python3
```

#### Task 2.5: Run Ansible Playbook

```bash
cd ansible
export CT301_IP="<ip-from-terraform>"

# Test connectivity
ansible ct301_samba -i inventory/hosts.yml -m ping

# Run playbook
ansible-playbook -i inventory/hosts.yml playbooks/ct301-samba.yml --ask-vault-pass
```

**Expected result**: All tasks complete successfully, Samba services running.

---

### Part 3: Testing & Verification

#### Task 3.1: Verify Services

```bash
ssh root@$CT301_IP "systemctl status smbd nmbd"
ssh root@$CT301_IP "pdbedit -L -v"
ssh root@$CT301_IP "testparm -s"
```

#### Task 3.2: Test from macOS

**CLI test**:
```bash
smbclient -L //$CT301_IP -U media
# Enter password when prompted
# Should list [storage] share

smbclient //$CT301_IP/storage -U media
# Test commands: ls, cd media, ls
```

**GUI test**:
1. Finder → Cmd+K
2. `smb://$CT301_IP/storage`
3. Connect with: media / password
4. Should mount successfully

**Write test**:
```bash
echo "test" > test.txt
# Copy to mounted share
ssh root@$CT301_IP "ls -l /mnt/storage/test.txt"
# Verify owner: media:media
```

#### Task 3.3: Test Large File Streaming

1. Browse to `/mnt/storage/media/library` via SMB
2. Open a large video file (MKV/MP4) directly
3. Verify:
   - Playback starts without downloading
   - Seeking is responsive
   - No buffering issues

**Monitor during playback**:
```bash
ssh root@192.168.1.56 "pct top 301"
# CPU should be low (<10%)
```

---

## Client Access

### macOS

**Finder**:
1. Go → Connect to Server (Cmd+K)
2. Server: `smb://$CT301_IP/storage`
3. Connect, enter credentials
4. Mounts as `/Volumes/storage`

**Command line**:
```bash
mount_smbfs //media:password@$CT301_IP/storage /Volumes/storage
```

### Windows

**File Explorer**:
1. This PC → Map network drive
2. Folder: `\\$CT301_IP\storage`
3. "Connect using different credentials"
4. Username: `media`, Password: (from vault)

**Command line**:
```cmd
net use Z: \\$CT301_IP\storage /user:media
```

### Linux

**Install cifs-utils**:
```bash
sudo apt install cifs-utils
```

**Mount**:
```bash
sudo mount -t cifs //$CT301_IP/storage /mnt/storage \
  -o username=media,password=XXX,uid=1000,gid=1000
```

**Persistent mount** (`/etc/fstab`):
```
//$CT301_IP/storage /mnt/storage cifs username=media,password=XXX,uid=1000,gid=1000 0 0
```

---

## Security Considerations

### What We're Doing ✅

- **Password authentication**: Required for all access
- **Single user**: Reduced attack surface, easier to audit
- **LAN-only**: Not exposed to internet
- **Encrypted secrets**: Password stored in Ansible Vault
- **SMB2+ only**: SMB1 disabled (security best practice)
- **Standard logging**: Activity logged to `/var/log/samba/`

### What We're NOT Doing ❌

- **Network trust**: Not trusting IP ranges without password
- **Guest access**: No anonymous access
- **Multiple users**: Unnecessary complexity for homelab
- **Service discovery**: No Avahi/mDNS (DNS handled later)
- **Workgroup integration**: No Windows domain join

### Future Hardening (Optional)

If needed later:
- Add firewall rules (limit to specific client IPs)
- Enable Samba audit logging (detailed access logs)
- Configure fail2ban (brute force protection)
- Require VPN for external access
- Add second backup user (read-only)

---

## Maintenance

### Password Rotation

```bash
cd ansible
ansible-vault edit vars/secrets.yml
# Update samba_media_password

ansible-playbook -i inventory/hosts.yml playbooks/ct301-samba.yml --tags users
```

Update credentials on all clients after rotation.

### View Logs

```bash
ssh root@$CT301_IP "tail -f /var/log/samba/samba.log"
```

### Check Connected Clients

```bash
ssh root@$CT301_IP "smbstatus"
```

### Restart Services

```bash
ssh root@$CT301_IP "systemctl restart smbd nmbd"
```

---

## Backup & Recovery

### What to Backup

- [ ] Samba configuration: `/etc/samba/smb.conf`
- [ ] User database: `/var/lib/samba/private/passdb.tdb`
- [ ] Ansible Vault password (secure location)

### What NOT to Backup

- ❌ `/mnt/storage` contents (backed up separately by CT300)
- ❌ Container OS (reproducible via Terraform)

### Recovery Procedure

If CT301 is destroyed:

```bash
# 1. Recreate container
cd terraform
terraform apply

# 2. Reconfigure Samba
cd ../ansible
export CT301_IP="<new-ip>"
ansible-playbook -i inventory/hosts.yml playbooks/ct301-samba.yml

# 3. Restore user database (if needed)
scp backup-passdb.tdb root@$CT301_IP:/var/lib/samba/private/passdb.tdb
ssh root@$CT301_IP "systemctl restart smbd"
```

**Recovery time**: ~10 minutes

---

## Troubleshooting

### Container Won't Start

```bash
ssh root@192.168.1.56
pct start 301
journalctl -xe
```

Check:
- VMID 301 not already used
- Debian template exists
- /mnt/storage mounted on host

### Can't Connect to Share

```bash
# Check services running
ssh root@$CT301_IP "systemctl status smbd nmbd"

# Test from container
ssh root@$CT301_IP "smbclient -L localhost -U media"

# Check firewall (should be disabled on container)
ssh root@$CT301_IP "iptables -L"
```

### Permission Denied

```bash
# Check mount point
ssh root@$CT301_IP "ls -ld /mnt/storage"
# Should show: drwxrwxr-x media media

# Check Samba user
ssh root@$CT301_IP "pdbedit -L"
# Should list: media:1000

# Test permissions
ssh root@$CT301_IP "sudo -u media touch /mnt/storage/test"
```

### Slow Performance

```bash
# Check container resources
ssh root@192.168.1.56 "pct top 301"

# Verify socket options
ssh root@$CT301_IP "testparm -s | grep socket"

# Check for I/O wait
ssh root@$CT301_IP "top"
# Look at %wa (I/O wait)
```

---

## File Structure

### Terraform

```
terraform/
├── main.tf                          # Provider config
├── variables.tf                     # Variable definitions
├── terraform.tfvars                 # Secrets (git-ignored)
└── containers/
    └── ct301-samba.tf              # Container definition
```

### Ansible

```
ansible/
├── inventory/
│   └── hosts.yml                    # Updated with CT301
├── roles/
│   └── samba/
│       ├── tasks/
│       │   └── main.yml            # Installation tasks
│       ├── templates/
│       │   └── smb.conf.j2         # Samba config template
│       └── handlers/
│           └── main.yml            # Service handlers
├── playbooks/
│   └── ct301-samba.yml             # Main playbook
└── vars/
    └── secrets.yml                  # Samba password (encrypted)
```

### Documentation

```
docs/
├── guides/
│   └── accessing-samba-share.md    # Client setup guide
├── reference/
│   └── ct301-samba-reference.md    # Quick reference
└── plans/
    └── samba-container-implementation-plan.md  # This file
```

---

## Success Criteria

Deployment is successful when:

- [ ] Container created and running (`pct list | grep 301`)
- [ ] /mnt/storage mounted in container
- [ ] Samba services active (`systemctl status smbd nmbd`)
- [ ] media user configured in Samba (`pdbedit -L`)
- [ ] SMB share accessible from macOS
- [ ] Large file streaming works (no buffering)
- [ ] Write permissions correct (media:media ownership)
- [ ] Password stored securely in Ansible Vault
- [ ] Documentation updated

---

## Time Estimate

- **Terraform provisioning**: 2-3 minutes
- **Ansible configuration**: 5-7 minutes
- **Testing & verification**: 10-15 minutes
- **Documentation**: 5 minutes

**Total**: ~25-30 minutes

---

## Rollback Plan

If something goes wrong:

```bash
# Stop and destroy container
cd terraform
terraform destroy -target=proxmox_virtual_environment_container.ct301_samba

# Or via Proxmox CLI
ssh root@192.168.1.56
pct stop 301
pct destroy 301

# Remove from inventory
# Edit ansible/inventory/hosts.yml
# Delete ct301_samba section
```

**No risk to existing infrastructure** - CT301 is isolated and new.

---

## Next Steps After Implementation

1. **Document actual IP**: Update this plan with CT301's actual IP address
2. **Set up clients**: Connect all your devices (laptop, PCs)
3. **Monitor usage**: Check logs after first week
4. **Consider enhancements**:
   - Add to monitoring system
   - Set up log rotation
   - Configure automatic updates

---

## Appendix: Complete File Contents

### A1. Terraform Container Definition

**File**: `terraform/containers/ct301-samba.tf`

```hcl
# CT301: Samba File Server
# Purpose: SMB file sharing for /mnt/storage access
# Optimized for large file streaming

resource "proxmox_virtual_environment_container" "ct301_samba" {
  description = "Samba file server for /mnt/storage"
  node_name   = "homelab"
  vm_id       = 301

  # Use Debian 12 template (must exist on Proxmox host)
  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  # Privileged container (required for mount points)
  unprivileged = false

  # Startup configuration
  started = true
  startup {
    order      = 301
    up_delay   = 30
    down_delay = 30
  }

  # Resource allocation
  cpu {
    cores = 1
  }

  memory {
    dedicated = 1024  # 1GB RAM
    swap      = 512   # 512MB swap
  }

  # Disk configuration
  disk {
    datastore_id = "local-lvm"
    size         = 8  # 8GB system disk
  }

  # Network configuration
  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    enabled = true
    # Use DHCP - consistent with other containers
  }

  # Mount /mnt/storage from host
  mount_point {
    volume = "/mnt/storage"
    path   = "/mnt/storage"
    acl    = false
    backup = false
    quota  = false
    # Read-write access needed
    read_only = false
    replicate = false
    shared    = false
  }

  # Console configuration
  console {
    enabled    = true
    type       = "shell"
    tty_count  = 2
  }

  # Features
  features {
    nesting = false  # Not needed for Samba
  }

  # Tags for organization
  tags = ["infrastructure", "file-sharing", "samba"]
}

# Output container IP for Ansible inventory
output "ct301_samba_ip" {
  value       = proxmox_virtual_environment_container.ct301_samba.initialization[0].ip_config[0].ipv4[0].address
  description = "IP address of Samba container (CT301)"
}
```

### A2. Ansible Tasks

**File**: `ansible/roles/samba/tasks/main.yml`

```yaml
---
# Samba installation and configuration tasks

- name: Update apt cache
  apt:
    update_cache: yes
    cache_valid_time: 3600
  tags: [samba, install]

- name: Install Samba packages
  apt:
    name:
      - samba
      - samba-common-bin
      - cifs-utils  # Useful for testing
    state: present
  tags: [samba, install]

- name: Ensure media group exists
  group:
    name: media
    gid: 1000
    state: present
  tags: [samba, users]

- name: Ensure media user exists
  user:
    name: media
    uid: 1000
    group: media
    groups: []
    shell: /bin/bash
    create_home: yes
    home: /home/media
    state: present
  tags: [samba, users]

- name: Ensure /mnt/storage exists and has correct permissions
  file:
    path: /mnt/storage
    state: directory
    owner: media
    group: media
    mode: '0775'
  tags: [samba, permissions]

- name: Deploy Samba configuration
  template:
    src: smb.conf.j2
    dest: /etc/samba/smb.conf
    owner: root
    group: root
    mode: '0644'
    validate: 'testparm -s %s'
  notify: restart samba
  tags: [samba, config]

- name: Set Samba password for media user
  shell: |
    (echo "{{ samba_media_password }}"; echo "{{ samba_media_password }}") | smbpasswd -a -s media
  args:
    creates: /var/lib/samba/private/passdb.tdb
  no_log: true  # Don't log password
  tags: [samba, users]

- name: Enable media user in Samba
  shell: smbpasswd -e media
  changed_when: false
  tags: [samba, users]

- name: Ensure Samba services are enabled and started
  systemd:
    name: "{{ item }}"
    enabled: yes
    state: started
  loop:
    - smbd
    - nmbd
  tags: [samba, service]

- name: Create Samba log directory
  file:
    path: /var/log/samba
    state: directory
    owner: root
    group: root
    mode: '0755'
  tags: [samba, logging]
```

### A3. Samba Configuration Template

**File**: `ansible/roles/samba/templates/smb.conf.j2`

```ini
# Samba configuration for CT301
# Generated by Ansible - DO NOT EDIT MANUALLY

[global]
   # Server identification
   workgroup = WORKGROUP
   server string = Homelab Storage Server (CT301)
   netbios name = samba

   # Security configuration
   security = user
   passdb backend = tdbsam
   map to guest = never
   guest account = nobody

   # Disable printer sharing
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

   # Logging
   log file = /var/log/samba/%m.log
   max log size = 1000
   log level = 1

   # Performance tuning for large files
   # Optimized for movie file streaming
   socket options = SO_RCVBUF=524288 SO_SNDBUF=524288
   read raw = yes
   write raw = yes
   max xmit = 65536
   aio read size = 16384
   aio write size = 16384
   use sendfile = yes

   # Wide links configuration (required for MergerFS symlinks)
   # MergerFS may use symlinks for file distribution
   unix extensions = no
   allow insecure wide links = yes

   # Disable unnecessary services
   wins support = no
   dns proxy = no

   # Modern SMB protocol versions only
   # Disable SMB1 for security
   server min protocol = SMB2
   client min protocol = SMB2

# Storage share - entire /mnt/storage pool
[storage]
   comment = Homelab Storage Pool (MergerFS)
   path = /mnt/storage
   browseable = yes
   writable = yes

   # Authentication
   valid users = media
   guest ok = no

   # Force ownership to media user
   force user = media
   force group = media

   # Permission masks (match existing storage permissions)
   create mask = 0664
   directory mask = 0775
   force create mode = 0664
   force directory mode = 0775

   # Performance
   wide links = yes
   follow symlinks = yes

   # Disable veto files (allow all file types)
   veto files = /._*/.DS_Store/
   delete veto files = yes
```

### A4. Samba Handlers

**File**: `ansible/roles/samba/handlers/main.yml`

```yaml
---
# Samba service handlers

- name: restart samba
  systemd:
    name: "{{ item }}"
    state: restarted
  loop:
    - smbd
    - nmbd
  listen: restart samba
```

### A5. Samba Playbook

**File**: `ansible/playbooks/ct301-samba.yml`

```yaml
---
# Playbook for configuring CT301 (Samba file server)

- name: Configure Samba container (CT301)
  hosts: ct301_samba
  become: yes
  gather_facts: yes

  vars_files:
    - ../vars/secrets.yml

  pre_tasks:
    - name: Wait for container to be reachable
      wait_for_connection:
        timeout: 300
        delay: 10
      tags: always

    - name: Gather facts after connection
      setup:
      tags: always

  roles:
    - role: samba
      tags: [samba]

  post_tasks:
    - name: Display Samba server information
      debug:
        msg:
          - "Samba server configured successfully!"
          - "Access via: \\\\{{ ansible_default_ipv4.address }}\\storage"
          - "Username: media"
          - "Password: (stored in Ansible Vault)"
      tags: always
```

---

**This plan follows the same IaC patterns as CT300 (backup container) and fits cleanly into your existing infrastructure.**

---

**Last Updated**: 2025-01-11
