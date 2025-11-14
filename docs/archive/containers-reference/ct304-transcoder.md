# CT304: Transcoder Container

**CTID**: 304
**Hostname**: transcoder
**Type**: IaC-managed (Terraform + Ansible)
**Status**: ✅ **DEPLOYED**
**IP Address**: 192.168.1.77
**Purpose**: Video transcoding with FFmpeg using Intel Arc A380 GPU hardware acceleration

---

## Overview

CT304 is the IaC-managed transcoding container, providing automated video transcoding using FFmpeg with Intel Arc A380 GPU hardware acceleration for efficient H.265/HEVC encoding.

This container is fully managed via Infrastructure as Code:
- **Terraform**: Creates and provisions the LXC container
- **Ansible**: Installs software, configures GPU passthrough, deploys scripts

---

## Specifications

### Hardware

| Resource | Value |
|----------|-------|
| **CPU** | 4 cores |
| **RAM** | 8GB |
| **Swap** | 2GB |
| **Disk** | 20GB (local-lvm) |
| **Network** | Static: 192.168.1.77/24 |
| **Privileges** | Privileged (required for GPU passthrough) |

### Storage Mounts

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `/mnt/storage/media/staging` | `/mnt/staging` | Staging directory for media transcoding pipeline |

**Note**: Container has access to staging directory where raw and transcoded files are managed.

### GPU Passthrough

| Device | Type | Purpose |
|--------|------|---------|
| `/dev/dri/card1` | Intel Arc A380 | GPU device for hardware acceleration |
| `/dev/dri/renderD128` | Intel Arc A380 | Render node for VA-API |

**Hardware Encoding Support**:
- H.265/HEVC encoding (8-bit, 10-bit)
- H.264/AVC encoding
- VA-API acceleration
- QuickSync Video

---

## Software Stack

### Installed Packages

- **FFmpeg**: With Intel QSV/VA-API support
- **Intel Media Driver**: For Arc GPU hardware acceleration
- **Utilities**: vim, htop, curl, wget, git, vainfo

### User Configuration

- **User**: `media`
- **UID/GID**: 1000:1000
- **Groups**: `media`, `video` (44), `render` (105)
- **Home**: `/home/media`
- **Scripts**: `/home/media/scripts/`

---

## Deployed Scripts

| Script | Purpose | Location |
|--------|---------|----------|
| `transcode-queue.sh` | Automated hardware-accelerated transcoding | `/home/media/scripts/` |

---

## IaC Components

### Terraform

**File**: `terraform/ct304-transcoder.tf`

**Resources**:
- `proxmox_virtual_environment_container.transcoder`

**Outputs**:
- `transcoder_container_id`: Container ID (304)
- `transcoder_container_ip`: IP address (192.168.1.77/24)

**Note**: GPU passthrough must be configured via Ansible as the Terraform BPG provider doesn't support LXC device passthrough configuration.

### Ansible

**Playbook**: `ansible/ct304-transcoder.yml`

**Roles**:
1. `common`: System setup, SSH keys, media user
2. `intel_gpu_passthrough`: Intel Arc A380 GPU passthrough and driver installation

**Inventory**: `ansible/inventory/hosts.yml` → `transcoder_containers.ct304`

---

## Deployment

**Quick start**:

```bash
# 1. Create container
cd terraform && terraform apply

# 2. Run Ansible to configure GPU passthrough
cd ansible
ansible-playbook ct304-transcoder.yml
```

---

## Usage

### Transcode Media Files

```bash
ssh homelab "pct enter 304"
su - media
./scripts/transcode-queue.sh
```

**Input**: Files in `/mnt/staging/1-ripped/`
**Output**: Transcoded H.265 files in `/mnt/staging/2-ready/`

### Verify GPU Acceleration

```bash
# Check VA-API capabilities
vainfo --display drm --device /dev/dri/renderD128

# Verify devices exist
ls -la /dev/dri/

# Check media user group membership
id media
```

---

## Maintenance

### Update FFmpeg

```bash
# Re-run Ansible playbook
ansible-playbook ansible/ct304-transcoder.yml
```

### Monitor Transcoding

```bash
# Inside container
htop  # Watch CPU/memory usage
watch -n 1 'ls -lh /mnt/staging/1-ripped/ /mnt/staging/2-ready/'
```

---

## Transcoding Pipeline

### Directory Structure

```
/mnt/staging/
├── 0-raw/          # Raw MakeMKV output (input for organization)
├── 1-ripped/       # Organized, ready to transcode
│   ├── movies/
│   └── tv/
└── 2-ready/        # Transcoded H.265 output (ready for Jellyfin)
    ├── movies/
    └── tv/
```

### Typical Workflow

1. **Rip**: CT302 rips disc → `0-raw/`
2. **Organize**: Organize script → `1-ripped/`
3. **Transcode**: CT304 transcodes → `2-ready/` (you are here)
4. **Promote**: Move to library for CT305 (Jellyfin)

---

## Network

- **Interface**: eth0
- **Bridge**: vmbr0
- **IP Assignment**: Static (192.168.1.77/24)
- **Gateway**: 192.168.1.1

---

## Tags

- `media`: Media pipeline component
- `iac`: Infrastructure as Code managed
- `transcoder`: Video transcoding function
- `gpu`: GPU-accelerated

---

## Related Documentation

- [Transcoding Container Setup Guide](../guides/transcoding-container-setup.md)
- [Intel GPU Passthrough Role README](../../ansible/roles/intel_gpu_passthrough/README.md)
- [Media Pipeline Quick Reference](../reference/media-pipeline-quick-reference.md)
- [Media Pipeline v2 Guide](../guides/media-pipeline-v2.md)

---

**Created**: 2025-11-12
**Status**: ✅ Production ready
**Hardware**: Intel Arc A380 GPU with QSV/VA-API support
