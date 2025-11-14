# CT302: Ripper Container

**CTID**: 302  
**Hostname**: ripper  
**Type**: IaC-managed (Terraform + Ansible)  
**Status**: ✅ **DEPLOYED - 2025-11-11**  
**IP Address**: 192.168.1.70  
**Purpose**: Blu-ray/DVD ripping with MakeMKV

---

## Deployment History

### 2025-11-11: Initial Deployment - SUCCESS ✅

**Deployment Time**: ~20 minutes total
- Terraform: 5 seconds (container creation)
- Ansible: ~15 minutes (MakeMKV v1.18.2 compilation)

**Issues Encountered & Fixed**:
1. MakeMKV BIN EULA directory missing - Fixed by creating tmp/ directory first
2. `pct restart` command doesn't exist - Fixed by using `pct stop && pct start`

**Security Enhancements Implemented**:
- Restricted storage mount: Only `/mnt/storage/media/staging` → `/mnt/staging`
- Script auto-detection of mount path
- Principle of least privilege applied (ripper cannot access full media library)

**Final Verification**:
- ✅ Media user created (UID 1000, GID 1000, cdrom group)
- ✅ MakeMKV v1.18.2 installed and functional
- ✅ Optical drives accessible (`/dev/sr0`, `/dev/sg4`)
- ✅ Staging directory mounted correctly
- ✅ Script deployed with path auto-detection
- ✅ All tests passed - Production ready

---

## Overview

CT302 is the IaC-managed version of CT200 (ripper-new), providing automated Blu-ray and DVD ripping using MakeMKV with optical drive passthrough.

This container is fully managed via Infrastructure as Code:
- **Terraform**: Creates and provisions the LXC container
- **Ansible**: Installs software, configures passthrough, deploys scripts

---

## Specifications

### Hardware

| Resource | Value |
|----------|-------|
| **CPU** | 2 cores |
| **RAM** | 4GB |
| **Swap** | 2GB |
| **Disk** | 8GB (local-lvm) |
| **Network** | DHCP (vmbr0) |
| **Privileges** | Privileged (required for device passthrough) |

### Storage Mounts

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `/mnt/storage/media/staging` | `/mnt/staging` | Staging directory for ripped media (least privilege) |

**Note**: Container only has access to staging directory, not entire media library. This follows security best practices.

### Device Passthrough

| Device | Type | Purpose |
|--------|------|---------|
| `/dev/sr0` | Block (11:0) | Optical drive (CD/DVD/Blu-ray) |
| `/dev/sg4` | SCSI generic (21:4) | Optical drive (SCSI access) |

---

## Software Stack

### Installed Packages

- **MakeMKV v1.18.2**: Compiled from source (OSS + BIN)
- **Build tools**: gcc, make, pkg-config
- **Libraries**: Qt5, ffmpeg, OpenGL, OpenSSL
- **Utilities**: vim, htop, curl, wget, git

### User Configuration

- **User**: `media`
- **UID/GID**: 1000:1000
- **Groups**: `media`, `cdrom` (24)
- **Home**: `/home/media`
- **Scripts**: `/home/media/scripts/`

---

## Deployed Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `rip-disc.sh` | Automated disc ripping | `/home/media/scripts/` |

---

## Configuration Files

### MakeMKV Settings

**Location**: `/home/media/.MakeMKV/settings.conf`

**Managed by**: Ansible template from encrypted vault

**Contents**:
- Beta key (updated monthly)
- Default output filename: `%t` (title name)
- Default selection: `+sel:all` (all tracks)

---

## IaC Components

### Terraform

**File**: `terraform/ct302-ripper.tf`

**Resources**:
- `proxmox_virtual_environment_container.ripper`

**Outputs**:
- `ripper_container_id`: Container ID (302)

### Ansible

**Playbook**: `ansible/playbooks/ct302-ripper.yml`

**Roles**:
1. `common`: System setup, SSH keys, media user
2. `makemkv`: MakeMKV installation and configuration
3. `optical_drive_passthrough`: Device passthrough (runs on host)

**Secrets**: `ansible/vars/makemkv_secrets.yml` (encrypted)

**Inventory**: `ansible/inventory/hosts.yml` → `ripper_containers.ct302`

---

## Deployment

See [CT302 Deployment Guide](../guides/ct302-ripper-deployment.md) for full instructions.

**Quick start**:

```bash
# 1. Encrypt secrets
ansible-vault encrypt ansible/vars/makemkv_secrets.yml --vault-password-file ~/.vault_pass

# 2. Create container
cd terraform && terraform apply

# 3. Get IP and update inventory
ssh homelab "pct exec 302 -- ip -4 addr show eth0 | grep inet"

# 4. Run Ansible
cd ansible
ansible-playbook playbooks/ct302-ripper.yml --vault-password-file ~/.vault_pass
```

---

## Usage

### Rip a Movie

```bash
ssh homelab "pct enter 302"
su - media
./scripts/rip-disc.sh movie "Movie Name"
```

**Output**: `/mnt/storage/media/staging/1-ripped/movies/Movie_Name_YYYY-MM-DD/`

### Rip a TV Show Episode Disc

```bash
./scripts/rip-disc.sh show "Show Name" "S01 Disc1"
```

**Output**: `/mnt/storage/media/staging/1-ripped/tv/Show_Name/S01_Disc1_YYYY-MM-DD/`

---

## Maintenance

### Update MakeMKV Beta Key

Beta keys expire monthly. Get latest from:  
https://forum.makemkv.com/forum/viewtopic.php?t=1053

```bash
ansible-vault edit ansible/vars/makemkv_secrets.yml --vault-password-file ~/.vault_pass
# Update makemkv_beta_key

ansible-playbook ansible/playbooks/ct302-ripper.yml --vault-password-file ~/.vault_pass --tags makemkv
```

### Upgrade MakeMKV Version

```bash
# Edit version in role defaults
vim ansible/roles/makemkv/defaults/main.yml
# Change: makemkv_version: "1.18.3"

# Re-run playbook
ansible-playbook ansible/playbooks/ct302-ripper.yml --vault-password-file ~/.vault_pass --tags makemkv
```

---

## Comparison with CT200

| Aspect | CT200 (Manual) | CT302 (IaC) |
|--------|---------------|-------------|
| **Creation** | Proxmox UI | Terraform |
| **Software** | Manual install | Ansible role |
| **Configuration** | Manual | Ansible playbook |
| **Scripts** | Manual copy | Ansible deployment |
| **Reproducible** | ❌ | ✅ |
| **Disaster Recovery** | Manual rebuild | `terraform apply && ansible-playbook` |
| **Version Control** | ❌ | ✅ Git-tracked |
| **Secrets** | Plain text | Encrypted vault |

---

## Network

- **Interface**: eth0
- **Bridge**: vmbr0
- **IP Assignment**: DHCP
- **IP Address**: 192.168.1.70 (assigned 2025-11-11)

---

## Tags

- `media`: Media pipeline component
- `iac`: Infrastructure as Code managed
- `ripper`: Disc ripping function

---

## Related Documentation

- [Deployment Guide](../guides/ct302-ripper-deployment.md)
- [MakeMKV Role README](../../ansible/roles/makemkv/README.md)
- [Optical Drive Passthrough Role README](../../ansible/roles/optical_drive_passthrough/README.md)
- [Media Pipeline Quick Reference](../reference/media-pipeline-quick-reference.md)

---

**Created**: 2025-11-11  
**Deployed**: 2025-11-11  
**Status**: ✅ Production ready  
**Next Step**: Test with actual disc ripping, plan cutover from CT200
