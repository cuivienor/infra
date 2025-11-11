# CT301: Samba File Server

**CTID**: 301  
**Hostname**: samba  
**Type**: IaC-managed (Terraform + Ansible)  
**Status**: ✅ **DEPLOYED - 2025-11-11**  
**IP Address**: 192.168.1.82 (static)  
**Purpose**: SMB file sharing for `/mnt/storage` access

---

## Deployment History

### 2025-11-11: Initial Deployment - SUCCESS ✅

**Deployment Time**: ~7 minutes total
- Terraform: 5 seconds (container creation)
- Ansible: ~7 minutes (Samba installation and configuration)

**Final Verification**:
- ✅ Container created with static IP (192.168.1.82)
- ✅ Samba packages installed (smbd, nmbd)
- ✅ Media user created (UID 1000, GID 1000)
- ✅ Media user configured in Samba with password
- ✅ `/mnt/storage` mounted and accessible
- ✅ SMB share accessible from LAN clients
- ✅ Configuration optimized for large file streaming
- ✅ All tests passed - Production ready

---

## Overview

CT301 is a dedicated Samba file server providing SMB/CIFS network access to the entire `/mnt/storage` MergerFS pool. Optimized for streaming large media files (movies, TV shows) to LAN clients.

This container is fully managed via Infrastructure as Code:
- **Terraform**: Creates and provisions the LXC container
- **Ansible**: Installs Samba, configures shares, manages users

---

## Specifications

### Hardware

| Resource | Value |
|----------|-------|
| **CPU** | 1 core |
| **RAM** | 1GB |
| **Swap** | 512MB |
| **Disk** | 8GB (local-lvm) |
| **Network** | Static IP (vmbr0) |
| **Privileges** | Privileged (required for mount points) |

### Storage Mounts

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `/mnt/storage` | `/mnt/storage` | Full MergerFS pool (read-write) |

**Note**: Container has full read-write access to entire storage pool for file sharing.

---

## Software Stack

### Installed Packages

- **Samba**: SMB/CIFS file server
- **samba-common-bin**: Samba utilities
- **cifs-utils**: SMB client utilities (for testing)

### User Configuration

- **User**: `media`
- **UID/GID**: 1000:1000
- **Groups**: `media`
- **Home**: `/home/media`
- **Samba Password**: Stored encrypted in `ansible/vars/secrets.yml`

---

## SMB Share Configuration

### Share Details

**Share Name**: `storage`  
**Path**: `/mnt/storage`  
**Access**: Authenticated users only (media user)

### Connection Information

| Platform | Connection String |
|----------|------------------|
| **Windows** | `\\192.168.1.82\storage` |
| **macOS/Linux** | `smb://192.168.1.82/storage` |

**Username**: `media`  
**Password**: See vault at `ansible/vars/secrets.yml`

### Performance Optimizations

Configuration optimized for large file streaming:
- Socket buffers: 512KB (SO_RCVBUF/SO_SNDBUF)
- Max transmit size: 64KB
- Async I/O enabled (16KB blocks)
- Sendfile enabled (zero-copy)
- SMB1 disabled (security)
- SMB2/SMB3 only

### Security

- No guest access (authentication required)
- Force user/group to `media` (consistent permissions)
- Wide links enabled (required for MergerFS symlinks)
- Unix extensions disabled (compatibility)
- Veto files: `._*`, `.DS_Store` (macOS metadata)

---

## Configuration Files

### Samba Configuration

**Location**: `/etc/samba/smb.conf`

**Managed by**: Ansible template (`ansible/roles/samba/templates/smb.conf.j2`)

**Key Settings**:
```ini
[global]
    workgroup = WORKGROUP
    server string = Homelab Storage Server (CT301)
    security = user
    server min protocol = SMB2

[storage]
    path = /mnt/storage
    valid users = media
    writable = yes
    force user = media
    force group = media
    create mask = 0664
    directory mask = 0775
```

---

## IaC Components

### Terraform

**File**: `terraform/ct301-samba.tf`

**Resources**:
- `proxmox_virtual_environment_container.samba`

**Outputs**:
- `samba_container_id`: Container ID (301)
- `samba_container_ip`: IP address (192.168.1.82/24)

### Ansible

**Playbook**: `ansible/playbooks/ct301-samba.yml`

**Role**: `samba` - Installs and configures Samba server

**Secrets**: `ansible/vars/secrets.yml` (encrypted)
- Variable: `samba_media_password`

**Inventory**: `ansible/inventory/hosts.yml` → `samba_containers.ct301_samba`

---

## Deployment

See [CT301 Setup Guide](../guides/ct301-samba-setup.md) for full instructions.

**Quick start**:

```bash
# 1. Create/edit secrets file
cd ansible
ansible-vault edit vars/secrets.yml --vault-password-file ../.vault_pass
# Set: samba_media_password: "your_secure_password"

# 2. Create container
cd ../terraform
terraform apply

# 3. Run Ansible
cd ../ansible
ansible-playbook playbooks/ct301-samba.yml --vault-password-file ../.vault_pass
```

---

## Usage

### Connect from macOS

**Finder**:
1. Go → Connect to Server (Cmd+K)
2. Server: `smb://192.168.1.82/storage`
3. Connect as: Registered User
4. Username: `media`
5. Password: (from vault)

**Command line**:
```bash
mount_smbfs //media@192.168.1.82/storage /Volumes/storage
```

### Connect from Windows

**File Explorer**:
1. Map network drive
2. Folder: `\\192.168.1.82\storage`
3. Username: `media`
4. Password: (from vault)

**Command line**:
```cmd
net use Z: \\192.168.1.82\storage /user:media
```

### Connect from Linux

**Mount**:
```bash
sudo apt install cifs-utils
sudo mkdir -p /mnt/homelab-storage
sudo mount -t cifs //192.168.1.82/storage /mnt/homelab-storage \
  -o username=media,password=YOUR_PASSWORD,uid=1000,gid=1000
```

**Persistent mount** (`/etc/fstab`):
```
//192.168.1.82/storage /mnt/homelab-storage cifs credentials=/root/.smbcredentials,uid=1000,gid=1000 0 0
```

---

## Operations

### Check Services

```bash
# Service status
ssh root@192.168.1.82 "systemctl status smbd nmbd"

# Connected clients
ssh root@192.168.1.82 "smbstatus"

# View logs
ssh root@192.168.1.82 "tail -f /var/log/samba/*.log"
```

### Restart Services

```bash
ssh root@192.168.1.82 "systemctl restart smbd nmbd"
```

### Test Configuration

```bash
# Validate config
ssh root@192.168.1.82 "testparm -s"

# Test local connection
ssh root@192.168.1.82 "smbclient -L localhost -U media"
```

### View Vault Password

```bash
cd ansible
ansible-vault view vars/secrets.yml --vault-password-file ../.vault_pass
```

---

## Maintenance

### Update Samba Configuration

```bash
# Edit template
vim ansible/roles/samba/templates/smb.conf.j2

# Apply changes
cd ansible
ansible-playbook playbooks/ct301-samba.yml --vault-password-file ../.vault_pass --tags config
```

### Change Media User Password

```bash
# Edit secrets
cd ansible
ansible-vault edit vars/secrets.yml --vault-password-file ../.vault_pass
# Update: samba_media_password

# Apply changes
ansible-playbook playbooks/ct301-samba.yml --vault-password-file ../.vault_pass --tags users
```

### Update Samba Package

```bash
# Re-run playbook (will update to latest available version)
cd ansible
ansible-playbook playbooks/ct301-samba.yml --vault-password-file ../.vault_pass --tags install
```

---

## Troubleshooting

### Can't Connect to Share

**Check services**:
```bash
ssh root@192.168.1.82 "systemctl status smbd nmbd"
```

**Restart if needed**:
```bash
ssh root@192.168.1.82 "systemctl restart smbd nmbd"
```

**Test from container**:
```bash
ssh root@192.168.1.82 "smbclient -L localhost -U media"
```

### Permission Denied

**Check mount point ownership**:
```bash
ssh root@192.168.1.82 "ls -ld /mnt/storage"
# Should show: drwxrwxr-x media media
```

**Test write access**:
```bash
ssh root@192.168.1.82 "sudo -u media touch /mnt/storage/test.txt"
ssh root@192.168.1.82 "sudo -u media rm /mnt/storage/test.txt"
```

### Slow Performance

**Check container resources**:
```bash
ssh homelab "pct top 301"
```

**Verify performance settings**:
```bash
ssh root@192.168.1.82 "testparm -s | grep -E 'socket|sendfile|aio'"
```

**Consider**:
- Increase RAM if container is swapping
- Add more CPU cores if consistently at 100%

### Mount Not Available

**Check on host**:
```bash
ssh homelab "pct mount 301"
```

**Check inside container**:
```bash
ssh root@192.168.1.82 "df -h /mnt/storage"
ssh root@192.168.1.82 "ls -la /mnt/storage"
```

---

## Network

- **Interface**: eth0
- **Bridge**: vmbr0
- **IP Assignment**: Static
- **IP Address**: 192.168.1.82/24
- **Gateway**: 192.168.1.1

---

## Tags

- `infrastructure`: Core infrastructure service
- `file-sharing`: SMB file sharing
- `samba`: Samba server
- `iac`: Infrastructure as Code managed

---

## Performance Notes

**Optimized for**:
- Large file streaming (movies, TV shows)
- Multiple concurrent connections
- LAN speeds (Gigabit Ethernet)

**Typical Performance**:
- Read speeds: ~110 MB/s (close to gigabit)
- Write speeds: ~100 MB/s
- Latency: Low (local network)

**Bottlenecks**:
- Network: Limited by gigabit Ethernet (125 MB/s theoretical)
- Storage: Limited by HDD speeds (~150 MB/s per disk)
- CPU: Minimal impact (1 core sufficient)

---

## Security Considerations

- **Container**: Privileged (required for mount points)
- **Authentication**: SMB password authentication only
- **Encryption**: SMB3 encryption available but not enforced
- **Network**: LAN-only access (no external exposure)
- **Password**: Stored encrypted in Ansible Vault
- **Protocol**: SMB1 disabled (security)

**Recommendations**:
- Keep Samba updated (security patches)
- Rotate media user password periodically
- Consider firewall rules if needed
- Enable SMB3 encryption for sensitive data

---

## Related Documentation

- [Setup Guide](../guides/ct301-samba-setup.md)
- [Samba Role README](../../ansible/roles/samba/)
- [Implementation Plan](../plans/samba-container-implementation-plan.md)
- [Media Pipeline Quick Reference](../reference/media-pipeline-quick-reference.md)

---

**Created**: 2025-11-11  
**Deployed**: 2025-11-11  
**Status**: ✅ Production ready  
**Next Step**: Test file sharing from various LAN clients
