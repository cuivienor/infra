# Homelab Current State

**Last Updated**: 2025-11-16  
**Status**: ✅ Full Infrastructure as Code - All containers managed by Terraform + Ansible  
**Remote Access**: ✅ Tailscale subnet routing with redundant routers

---

## System Overview

### Proxmox Host

| Component | Details |
|-----------|---------|
| **Hostname** | `homelab` |
| **IP Address** | `192.168.1.100/24` (Ansible-managed) |
| **OS** | Debian GNU/Linux 12 (bookworm) |
| **Kernel** | `6.8.12-10-pve` |
| **Proxmox Version** | `8.4.14` (pve-manager) |

### Hardware Specifications

#### CPU
- **Model**: Intel Core i5-9600K @ 3.70GHz
- **Cores**: 6 physical cores (no hyperthreading)
- **Architecture**: x86_64

#### Memory
- **Total RAM**: 32 GB
- **Swap**: 8 GB

#### Graphics/Transcoding Hardware

| Device | Type | DRI Device | Purpose |
|--------|------|------------|---------|
| **Intel Arc A380** | DG2 Graphics | `/dev/dri/card1`, `/dev/dri/renderD128` | Primary transcoding GPU |
| **NVIDIA GTX 1080** | GP104 | `/dev/dri/card0`, `/dev/dri/renderD129` | Secondary/Display GPU |

**Loaded Modules**: `i915` (Intel graphics driver)

#### Optical Drive
- **Device**: `/dev/sr0` (block device for disc access)
- **SCSI Generic**: `/dev/sg4` (for MakeMKV access)
- **Group**: `cdrom` (24)

#### Network
- **Primary Interface**: `eno1` (Ethernet)
- **Bridge**: `vmbr0` (192.168.1.56/24)

---

## Storage Configuration

### MergerFS Pool

**Mount Point**: `/mnt/storage`  
**Total Capacity**: 35TB  
**Used**: 4.6TB (14%)  
**Available**: 29TB

#### Data Disks

| Device | Mount Point | Size | Used | Type |
|--------|-------------|------|------|------|
| `/dev/sdc1` (WD101EDBZ) | `/mnt/disk1` | 9.1T | 4.1T | Data |
| `/dev/sdd1` (ST10000DM) | `/mnt/disk2` | 9.1T | ~200M | Data |
| `/dev/sdb1` (WD180EDGZ) | `/mnt/disk3` | 17T | ~24G | Data |
| `/dev/sda1` (WD180EDGZ) | `/mnt/parity` | 17T | 3.1T | Parity |

**MergerFS Policy**: `eppfrd` (Existing Path, Percentage Free space, Round-robin Distribution)
- Automatically distributes new files to disks with most free space
- All disks mounted by `/dev/disk/by-id/` for stability

### Proxmox Storage

| Storage | Type | Total | Used | Available |
|---------|------|-------|------|-----------|
| `local` | dir | 94 GB | ~8 GB | ~86 GB |
| `local-lvm` | lvmthin | 1.7 TB | ~130 GB | ~1.6 TB |
| `storage` | dir | 35 TB | 4.6 TB | 29 TB |

---

## Media Directory Structure

```
/mnt/storage/media/
├── library/          # New organized media (FileBot managed)
│   ├── movies/
│   └── tv/
├── movies/           # Legacy movie library (being migrated)
├── tv/               # Legacy TV library (being migrated)
└── staging/          # Media pipeline staging area
    ├── 1-ripped/     # Raw MakeMKV output
    ├── 2-remuxed/    # Remuxed files
    ├── 3-transcoded/ # Transcoded files
    └── 4-ready/      # Organized and ready to move to library
```

**Ownership**: `media:media` (UID/GID 1000:1000)  
**Permissions**: Directories `0775`

---

## LXC Container Inventory

### Active Containers (All IaC-Managed)

| CTID | Name | IP | Cores | RAM | Disk | Purpose |
|------|------|-----|-------|-----|------|---------|
| 300 | `backup` | 192.168.1.120 | 2 | 2 GB | 20 GB | Restic backup + Backrest UI |
| 301 | `samba` | 192.168.1.121 | 1 | 1 GB | 8 GB | Samba file server |
| 302 | `ripper` | 192.168.1.131 | 2 | 4 GB | 8 GB | MakeMKV Blu-ray ripping |
| 303 | `analyzer` | 192.168.1.133 | 2 | 4 GB | 12 GB | Media analysis & organization |
| 304 | `transcoder` | 192.168.1.132 | 4 | 8 GB | 20 GB | FFmpeg transcoding (Intel Arc GPU) |
| 305 | `jellyfin` | 192.168.1.130 | 4 | 8 GB | 32 GB | Media server (dual GPU) |
| 310 | `dns` | 192.168.1.110 | 1 | 1 GB | 8 GB | Backup DNS (AdGuard Home) |

**All containers**: Privileged, Debian 12, managed via Terraform + Ansible  
**Tags**: `iac`, `media`, plus role-specific tags  
**DNS**: Configured via Terraform variable `var.dns_servers` (default: 1.1.1.1, 8.8.8.8)

---

## Container Details

### CT300: Backup

**Type**: Privileged LXC  
**Storage Mount**: `/mnt/storage` → `/mnt/storage` (full storage access)  
**Purpose**: Restic backups to Backblaze B2 + Backrest UI

**Installed Software**:
- Restic (automated backups)
- Backrest UI (web-based management)

**Backup Policy**:
- Target: Backblaze B2 (`homelab-data`)
- Schedule: Daily at 2 AM
- Retention: 7 daily, 4 weekly, 6 monthly, 2 yearly
- Scope: All `/mnt/storage` data except media library

**Status**: ✅ Production

---

### CT301: Samba

**Type**: Privileged LXC  
**Storage Mount**: `/mnt/storage` → `/mnt/storage` (full storage access)  
**Purpose**: Samba network file shares

**Status**: ✅ Production

---

### CT302: Ripper

**Type**: Privileged LXC  
**Storage Mount**: `/mnt/storage/media/staging` → `/mnt/staging` (restricted access)  
**Purpose**: Blu-ray/DVD ripping with MakeMKV

**Hardware Passthrough**:
```bash
# Optical Drive Access (configured via Ansible)
lxc.cgroup2.devices.allow: c 11:0 rwm      # /dev/sr0 (block)
lxc.cgroup2.devices.allow: c 21:4 rwm      # /dev/sg4 (SCSI generic)
lxc.mount.entry: /dev/sr0 dev/sr0 none bind,optional,create=file
lxc.mount.entry: /dev/sg4 dev/sg4 none bind,optional,create=file
```

**Installed Software**:
- MakeMKV
- Media user (UID 1000, member of `cdrom` group)

**Status**: ✅ Production, optical drive passthrough working

---

### CT303: Analyzer

**Type**: Privileged LXC  
**Storage Mount**: `/mnt/storage/media` → `/mnt/media` (media directory access)  
**Purpose**: Media file analysis, validation, and organization

**Installed Software**:
- MediaInfo, mkvtoolnix, ffprobe
- FileBot (for organization)
- Media user (UID 1000)

**Status**: ✅ Production

---

### CT304: Transcoder

**Type**: Privileged LXC  
**Storage Mount**: `/mnt/storage/media/staging` → `/mnt/staging` (restricted access)  
**Purpose**: Hardware-accelerated video transcoding

**Hardware Passthrough**:
```bash
# Intel Arc A380 GPU (configured via Ansible)
lxc.cgroup2.devices.allow: c 226:0 rwm      # card1
lxc.cgroup2.devices.allow: c 226:1 rwm      # card1
lxc.cgroup2.devices.allow: c 226:128 rwm    # renderD128
lxc.mount.entry: /dev/dri/card1 dev/dri/card1 none bind,optional,create=file
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
```

**Installed Software**:
- FFmpeg (with VA-API support)
- Intel Media Driver (iHD)
- Media user (UID 1000, member of `video` and `render` groups)

**GPU Verification**:
```
vainfo: VA-API version 1.17 (libva 2.12.0)
Driver: Intel iHD driver for Intel(R) Gen Graphics
```

**Status**: ✅ Production, GPU passthrough working

---

### CT305: Jellyfin

**Type**: Privileged LXC  
**Storage Mounts**:
- `/mnt/storage/media/library` → `/media/library` (new organized library)
- `/mnt/storage/media` → `/media/legacy` (legacy movies/tv during migration)

**Purpose**: Media streaming server with hardware transcoding

**Hardware Passthrough**:
```bash
# Dual GPU Support (configured via Ansible)
# Intel Arc A380 (primary for VA-API)
lxc.cgroup2.devices.allow: c 226:0 rwm      # card1
lxc.cgroup2.devices.allow: c 226:1 rwm      # card1
lxc.cgroup2.devices.allow: c 226:128 rwm    # renderD128

# NVIDIA GTX 1080 (secondary, available but not primary)
lxc.cgroup2.devices.allow: c 226:129 rwm    # renderD129

lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
```

**Installed Software**:
- Jellyfin media server
- Intel VA-API drivers (iHD)
- Media user (UID 1000, member of `video` and `render` groups)

**Hardware Acceleration**:
- Intel Arc A380 (primary): AV1, HEVC, H.264 encode/decode via VA-API
- NVIDIA GTX 1080: Available for future use

**Status**: ✅ Production, dual GPU passthrough configured

---

### CT310: DNS (Backup)

**Type**: Privileged LXC  
**Purpose**: Backup DNS server with AdGuard Home (primary on Pi4)

**Installed Software**:
- AdGuard Home v0.107.69
- Local DNS rewrites for paniland.com services

**Configuration**:
- Web UI: http://192.168.1.110:3000
- DNS: 192.168.1.110:53
- 12 local DNS rewrites configured
- Ad blocking disabled (intentional)
- Config managed via Ansible template

**Status**: ✅ Production, failover DNS ready

---

## DNS Infrastructure

### Overview

**Primary DNS**: Pi4 (192.168.1.102)  
**Backup DNS**: CT310 (192.168.1.110)  
**Technology**: AdGuard Home v0.107.69

### Local DNS Rewrites

| Domain | IP | Service |
|--------|-----|---------|
| homelab.paniland.com | 192.168.1.100 | Proxmox host |
| pi3.paniland.com | 192.168.1.101 | Raspberry Pi 3 |
| pi4.paniland.com | 192.168.1.102 | Raspberry Pi 4 |
| dns.paniland.com | 192.168.1.110 | Backup DNS |
| backup.paniland.com | 192.168.1.120 | Backup container |
| samba.paniland.com | 192.168.1.121 | Samba container |
| jellyfin.paniland.com | 192.168.1.130 | Jellyfin |
| ripper.paniland.com | 192.168.1.131 | Ripper |
| transcoder.paniland.com | 192.168.1.132 | Transcoder |
| analyzer.paniland.com | 192.168.1.133 | Analyzer |
| jellyfin.local | 192.168.1.130 | Jellyfin (short) |
| samba.local | 192.168.1.121 | Samba (short) |

**Management**: Full IaC via Ansible role `adguard_home` and playbook `dns.yml`

---

## Remote Access (Tailscale)

### Overview

**Purpose**: Secure remote access to homelab services from anywhere  
**Technology**: Tailscale subnet routing with redundant routers  
**Tailnet**: pigeon-piano.ts.net

### Architecture

```
Remote Client (phone/laptop)
    ↓
Tailscale Network
    ↓
Subnet Routers (redundant):
  - Pi4 (primary) - 100.110.39.126
  - Proxmox (secondary) - 100.97.172.81
    ↓
Your LAN (192.168.1.0/24)
    ↓
DNS: Pi4 AdGuard → resolves *.paniland.com and *.home.arpa
    ↓
Services: Jellyfin, Proxmox, etc.
```

### Subnet Routers

| Host | Tailscale IP | Role | Routes |
|------|--------------|------|--------|
| Pi4 (192.168.1.102) | 100.110.39.126 | Primary | 192.168.1.0/24 |
| Proxmox (192.168.1.100) | 100.97.172.81 | Secondary | 192.168.1.0/24 |

**Features**:
- Automatic failover (if Pi4 down, Proxmox takes over)
- IP forwarding enabled on both hosts
- Auth keys managed via Terraform (90-day expiry, auto-regenerate)

### DNS Configuration

**Global DNS**: Pi4 AdGuard (192.168.1.102)  
**MagicDNS**: Disabled (tailnet-wide)  
**Split DNS Routes**:
- `*.paniland.com` → 192.168.1.102
- `*.home.arpa` → 192.168.1.102

**Important**: Pi4 router has `--accept-dns=false` to prevent circular DNS dependency. Since Pi4 IS the DNS server, it cannot use Tailscale's DNS resolver (100.100.100.100) which would point back to itself.

**Result**: Same URLs work locally and remotely:
- `https://jellyfin.paniland.com` → Caddy proxy → Jellyfin
- `ssh cuiv@pi4.home.arpa` → Direct SSH

### Access Control (ACLs)

**Managed via**: Terraform (`terraform/tailscale.tf`)

| Group | Access |
|-------|--------|
| `autogroup:admin` (you) | Full access to everything (`*:*`) |
| `group:friends` | Limited: proxy (80/443), Jellyfin direct (8096) |

**Tags**:
- `tag:subnet-router` - Applied to Pi4 and Proxmox routers
- `tag:server` - Available for future server tagging
- `tag:pc` - For personal devices

### Key Benefits

1. **Same URLs everywhere** - jellyfin.paniland.com works at home and remotely
2. **Ad-blocking follows you** - Pi4 AdGuard filters all DNS queries
3. **Redundant routing** - Pi4 down? Proxmox takes over automatically
4. **Granular friend access** - Share specific services via ACLs
5. **Mullvad compatibility** - Exit nodes still work alongside subnet routing

### Management Commands

```bash
# Check router status
ssh cuiv@192.168.1.102 "sudo tailscale status"
ssh cuiv@192.168.1.100 "sudo tailscale status"

# Verify routes
ssh cuiv@192.168.1.102 "sudo tailscale status --json | jq '.Self.PrimaryRoutes'"

# Check DNS config
ssh cuiv@192.168.1.102 "sudo tailscale dns status"

# Redeploy routers (after key rotation)
cd ansible && ansible-playbook playbooks/tailscale.yml
```

### Adding Friends

1. Edit `terraform/tailscale.tf`:
   ```hcl
   groups = {
     "group:friends" = ["friend@gmail.com"]
   }
   ```
2. Apply: `cd terraform && terraform apply`
3. Invite friend via Tailscale admin console
4. They install Tailscale, accept invite
5. They can access allowed services

### Auth Key Rotation

Auth keys expire after 90 days. Terraform handles regeneration:

```bash
cd terraform
terraform plan   # Shows key recreation
terraform apply  # Generates new keys

# Export to Ansible vault
terraform output -raw tailscale_pi4_auth_key | \
  ansible-vault encrypt_string --vault-password-file ../.vault_pass \
  --stdin-name vault_tailscale_pi4_auth_key

# Update ansible/vars/secrets.yml with new encrypted keys
# Re-run playbook to re-authenticate routers
cd ansible && ansible-playbook playbooks/tailscale.yml
```

**Status**: ✅ Production, tested with mobile remote access

---

## User Configuration

### User Strategy

**Principle**: Consistent user across all physical hosts, separate service user for media file ownership.

| Host Type | SSH User | Groups | Purpose |
|-----------|----------|--------|---------|
| Physical hosts (Proxmox, Pis) | `cuiv` | sudo, media* | Your interactive user |
| LXC Containers | `root` | - | Ansible configuration |

*media group only on hosts with media storage access

### Admin User (cuiv)

**On Physical Hosts** (Proxmox, pi3, pi4):
- **Username**: `cuiv`
- **Shell**: `/bin/bash`
- **Groups**: `sudo` (+ `media` on Proxmox)
- **SSH Key**: Deployed via Ansible
- **Sudo**: Passwordless (`NOPASSWD: ALL`)

**Usage**:
```bash
# SSH to any physical host
ssh cuiv@192.168.1.100  # Proxmox (homelab)
ssh cuiv@192.168.1.101  # pi3
ssh cuiv@192.168.1.102  # pi4

# SSH to containers (use root)
ssh root@192.168.1.130  # jellyfin
ssh root@192.168.1.120  # backup

# Run commands with sudo
sudo systemctl status ...

# Work with media files on Proxmox
sudo -u media ffmpeg ...  # New files owned by media:media
```

### Media User (Service Account)

**On Proxmox Host**:
- **Username**: `media`
- **UID**: 1000
- **GID**: 1000
- **Groups**: `media`, `cdrom`, `video`, `render`
- **Purpose**: File ownership for media storage

**In LXC Containers**:
All containers use `media` user with UID/GID 1000 for consistent file ownership across bind mounts.

| Container | Additional Groups |
|-----------|-------------------|
| CT302 (ripper) | `cdrom` |
| CT304 (transcoder) | `video`, `render` |
| CT305 (jellyfin) | `video`, `render` |

**Why Two Users?**
- `cuiv` = You, for interactive work and audit trail
- `media` = Service account for file ownership consistency
- Running `sudo -u media command` ensures new files have correct ownership

---

## Device Passthrough Configuration

### Intel Arc A380 GPU

**Host Devices**:
- `/dev/dri/card1` (Intel Arc card)
- `/dev/dri/renderD128` (Intel Arc render node)

**Groups**: `video` (226), `render` (104)

**Used By**: CT304 (transcoder), CT305 (jellyfin)

**Verification**:
```bash
pct exec 304 -- vainfo --display drm --device /dev/dri/renderD128
```

**Status**: ✅ Working (VA-API 1.17, Intel iHD driver)

---

### NVIDIA GTX 1080

**Host Devices**:
- `/dev/dri/card0` (NVIDIA card)
- `/dev/dri/renderD129` (NVIDIA render node)

**Used By**: CT305 (jellyfin, secondary GPU)

**Status**: ✅ Passed through, available for use

---

### Optical Drive (Blu-ray)

**Host Devices**:
- `/dev/sr0` (block device, major 11, minor 0)
- `/dev/sg4` (SCSI generic, major 21, minor 4)

**Group**: `cdrom` (24)

**Used By**: CT302 (ripper)

**Verification**:
```bash
pct exec 302 -- makemkvcon info disc:0
```

**Status**: ✅ Working

---

## Infrastructure as Code

### Terraform

**Location**: `terraform/`  
**Providers**:
- BPG Proxmox (`~> 0.50.0`) - Container management
- Tailscale (`~> 0.16`) - Remote access infrastructure

**Container Definitions**:
- `backup.tf` - Backup container
- `samba.tf` - Samba file server
- `ripper.tf` - Ripper with optical drive
- `analyzer.tf` - Media analyzer
- `transcoder.tf` - Transcoder with GPU
- `jellyfin.tf` - Jellyfin with dual GPU

**Tailscale Management**:
- `tailscale.tf` - ACLs, DNS, auth keys for remote access

**Status**: ✅ All containers + remote access managed by Terraform

---

### Ansible

**Location**: `ansible/`  
**Inventory**: `ansible/inventory/hosts.yml`

**Key Roles**:
- `common` - Base configuration for all containers
- `restic_backup` - Restic backup + Backrest UI
- `optical_drive_passthrough` - Optical drive device passthrough
- `intel_gpu_passthrough` - Intel Arc GPU passthrough
- `dual_gpu_passthrough` - Dual GPU passthrough for Jellyfin
- `makemkv` - MakeMKV installation and configuration
- `media_analyzer` - Media analysis tools (MediaInfo, FileBot)
- `jellyfin` - Jellyfin media server
- `adguard_home` - AdGuard Home DNS server
- `tailscale_subnet_router` - Tailscale subnet routing for remote access

**Playbooks**:
- `site.yml` - Main playbook for all containers
- `backup.yml` - Backup container
- `samba.yml` - Samba container
- `ripper.yml` - Ripper container
- `analyzer.yml` - Analyzer container
- `transcoder.yml` - Transcoder container
- `jellyfin.yml` - Jellyfin container
- `dns.yml` - DNS infrastructure (Pi4 + CT310)
- `tailscale.yml` - Tailscale subnet routers (Pi4 + Proxmox)

**Status**: ✅ All containers + remote access configured via Ansible

---

## Media Pipeline Workflow

1. **Rip** (CT302): Insert disc → MakeMKV → `/mnt/staging/1-ripped/`
2. **Remux** (CT303): Analyze & remux → `/mnt/staging/2-remuxed/`
3. **Transcode** (CT304): Hardware transcode → `/mnt/staging/3-transcoded/`
4. **Organize** (CT303): FileBot → `/mnt/staging/4-ready/`
5. **Promote** (CT303): Move to `/mnt/storage/media/library/`
6. **Serve** (CT305): Jellyfin streams from `/media/library/`

**Scripts Location**: `scripts/media/production/`

---

## Backup Strategy

### Restic → Backblaze B2

**Container**: CT300 (backup)

**Policy**:
- **Scope**: All `/mnt/storage` data except media library
- **Included**: Photos, documents, backups, e-books, audiobooks
- **Excluded**: Movies, TV shows, staging directories
- **Encryption**: Client-side (restic)
- **Schedule**: Daily at 2 AM
- **Retention**: 7 daily, 4 weekly, 6 monthly, 2 yearly

**3-2-1 Backup**:
1. ✅ Live data on MergerFS (35TB with SnapRAID parity)
2. ✅ Restic → Backblaze B2 (encrypted cloud)
3. ⏳ Future: Local/family member backup

---

## Quick Reference Commands

### Container Management

```bash
# List containers
ssh cuiv@homelab "sudo pct list"

# Enter container
ssh cuiv@homelab "sudo pct enter <CTID>"

# Start/stop container
ssh cuiv@homelab "sudo pct start <CTID>"
ssh cuiv@homelab "sudo pct stop <CTID>"

# View container config
ssh cuiv@homelab "sudo cat /etc/pve/lxc/<CTID>.conf"
```

### Verification

```bash
# Check storage
ssh cuiv@homelab "df -h /mnt/storage"

# Check GPU in transcoder
ssh cuiv@homelab "sudo pct exec 304 -- vainfo --display drm --device /dev/dri/renderD128"

# Check optical drive in ripper
ssh cuiv@homelab "sudo pct exec 302 -- ls -la /dev/sr0 /dev/sg4"

# Check Jellyfin GPU
ssh cuiv@homelab "sudo pct exec 305 -- vainfo --display drm --device /dev/dri/renderD128"
```

### Infrastructure as Code

```bash
# Terraform
cd terraform
terraform plan
terraform apply

# Ansible
cd ansible
ansible-playbook playbooks/site.yml --vault-password-file ../.vault_pass
ansible-playbook playbooks/site.yml --tags <tag> --check  # dry-run
```

---

**Document Status**: ✅ Current as of 2025-11-16  
**IaC Status**: ✅ 100% Infrastructure as Code  
**Remote Access**: ✅ Tailscale subnet routing operational  
**Maintenance**: Update when infrastructure changes occur
