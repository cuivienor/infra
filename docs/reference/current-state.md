# Homelab Current State

**Last Updated**: 2025-11-11  
**Generated From**: Live system inspection via SSH

---

## System Overview

### Proxmox Host

| Component | Details |
|-----------|---------|
| **Hostname** | `homelab` |
| **IP Address** | `192.168.1.56/24` |
| **OS** | Debian GNU/Linux 12 (bookworm) |
| **Kernel** | `6.8.12-10-pve` |
| **Proxmox Version** | `8.4.14` (pve-manager) |
| **Proxmox VE** | `8.4.0` |

### Hardware Specifications

#### CPU
- **Model**: Intel Core i5-9600K @ 3.70GHz
- **Cores**: 6 physical cores (no hyperthreading)
- **Threads**: 6
- **Sockets**: 1
- **Architecture**: x86_64

#### Memory
- **Total RAM**: 32 GB (31 GiB)
- **Used**: ~2.2 GiB
- **Available**: ~29 GiB
- **Swap**: 8 GiB (21 MiB used)

#### Graphics/Transcoding Hardware

| Device | Type | PCIe Slot | Purpose |
|--------|------|-----------|---------|
| **Intel Arc A380** | DG2 Graphics | `07:00.0` | Primary transcoding GPU |
| **NVIDIA GTX 1080** | GP104 | `01:00.0` | Secondary/Display GPU |

**DRI Devices**:
- `/dev/dri/card0` - NVIDIA GTX 1080
- `/dev/dri/card1` - Intel Arc A380
- `/dev/dri/renderD128` - Intel Arc (primary for transcoding)
- `/dev/dri/renderD129` - NVIDIA

**Loaded Modules**: `i915` (Intel graphics driver)

#### Optical Drive
- **Device**: `/dev/sr0` (block device for disc access)
- **SCSI Generic**: `/dev/sg4` (for MakeMKV access)
- **Group**: `cdrom`

#### Network
- **Primary Interface**: `eno1` (Ethernet)
- **Bridge**: `vmbr0` (192.168.1.56/24)
- **Wireless**: `wlp4s0` (Intel Dual Band Wireless-AC 3168NGW - not in use)

---

## Storage Configuration

### Host Storage

#### Boot/System Storage
- **Boot**: `/dev/nvme0n1p2` (1022M EFI partition)
- **Root**: `/dev/mapper/pve-root` (94G ext4, 9% used)

#### Data Disks (MergerFS Pool)

| Device | Mount Point | Size | Used | Available | Use% | Type |
|--------|-------------|------|------|-----------|------|------|
| `/dev/sdc1` (WD101EDBZ) | `/mnt/disk1` | 9.1T | 4.1T | 4.6T | 48% | Data |
| `/dev/sdd1` (ST10000DM) | `/mnt/disk2` | 9.1T | 205M | 8.6T | 1% | Data |
| `/dev/sdb1` (WD180EDGZ) | `/mnt/disk3` | 17T | 23G | 16T | 1% | Data |
| `/dev/sda1` (WD180EDGZ) | `/mnt/parity` | 17T | 3.1T | 13T | 20% | Parity |

**MergerFS Pool**:
- **Mount**: `/mnt/storage` (mergerfs)
- **Total Capacity**: 35T
- **Used**: 4.1T (13%)
- **Available**: 29T

**MergerFS Options**:
```
defaults,nonempty,allow_other,use_ino,cache.files=off,
moveonenospc=true,dropcacheonclose=true,category.create=eppfrd,minfreespace=200G
```

**Distribution Policy**: `eppfrd` (Existing Path, Percentage Free space, Round-robin Distribution)
- Automatically distributes new files across disks with most free space
- Requires directory structure to exist on all disks
- Updated 2025-11-11 from `mfs` to `eppfrd` for balanced usage

**Disk Identification**: All disks mounted by `/dev/disk/by-id/` for stability

### Proxmox Storage

| Storage | Type | Total | Used | Available | Use% |
|---------|------|-------|------|-----------|------|
| `local` | dir | 94 GB | 7.7 GB | 85 GB | 8.10% |
| `local-lvm` | lvmthin | 1.7 TB | 21 GB | 1.7 TB | 1.18% |
| `storage` | dir | 35 TB | 4.1 TB | 29 TB | 11.81% |

---

## Media Directory Structure

```
/mnt/storage/media/
├── library/          # Organized media ready for Jellyfin
├── movies/           # Movie library (managed by FileBot)
├── tv/               # TV show library (managed by FileBot)
└── staging/          # Media pipeline staging area
    ├── 1-ripped/     # Raw MakeMKV output
    ├── 2-remuxed/    # Remuxed files
    ├── 3-transcoded/ # Transcoded files
    └── 4-ready/      # Organized and ready to move to library
```

**Note**: Directory structure replicated across all three data disks (disk1, disk2, disk3) as of 2025-11-11 to enable MergerFS `eppfrd` distribution policy.

**Ownership**: `media:media` (UID/GID 1000:1000)  
**Permissions**: Directories `0775`, Files managed by scripts

---

## LXC Container Inventory

### Running Containers

| CTID | Name | Status | IP | Cores | RAM | Disk | Purpose |
|------|------|--------|-----|-------|-----|------|---------|
| 101 | `jellyfin` | Running | 192.168.1.128 | 2 | 6 GB | 8 GB | Media server |
| 200 | `ripper-new` | Running | 192.168.1.75 | 2 | 4 GB | 8 GB | Blu-ray ripping (MakeMKV) |
| 201 | `transcoder-new` | Running | 192.168.1.77 | 4 | 8 GB | 20 GB | Video transcoding (FFmpeg) |
| 202 | `analyzer` | Running | 192.168.1.72 | 2 | 4 GB | 12 GB | Media analysis tools |

### Stopped Containers (Legacy)

| CTID | Name | Status | Purpose | Notes |
|------|------|--------|---------|-------|
| 100 | `ripper` | Stopped | Old ripper | Being replaced by CT200 |
| 102 | `transcoder` | Stopped | Old transcoder | Being replaced by CT201 |

---

## Container Details

### CT101: Jellyfin (Media Server)

**Type**: Unprivileged  
**OS**: Ubuntu  
**Network**: DHCP on vmbr0  
**Storage Mount**: `/mnt/storage/media` → `/data` (container)

**Purpose**: Serves media library to clients

**Status**: ✅ Running  
**Notes**: Unprivileged container, no hardware passthrough needed

---

### CT200: Ripper-New (Active Production)

**Type**: Privileged  
**OS**: Debian  
**Network**: DHCP on vmbr0, Firewall disabled  
**Storage Mount**: `/mnt/storage` → `/mnt/storage` (unified path)  
**Tags**: `media`

**Hardware Passthrough**:
```bash
# Optical Drive Access
lxc.cgroup2.devices.allow: c 11:0 rwm      # /dev/sr0 (block)
lxc.cgroup2.devices.allow: c 21:4 rwm      # /dev/sg4 (SCSI generic)
lxc.mount.entry: /dev/sr0 dev/sr0 none bind,optional,create=file
lxc.mount.entry: /dev/sg4 dev/sg4 none bind,optional,create=file
```

**Installed Software**:
- MakeMKV (`makemkvcon` available)
- Media user (UID 1000, member of `cdrom` group)

**Purpose**: Rip Blu-ray discs to `/mnt/storage/media/staging/0-raw/`

**Status**: ✅ Running, actively used for ripping

---

### CT201: Transcoder-New (Active Production)

**Type**: Privileged  
**OS**: Debian  
**Network**: DHCP on vmbr0, Firewall disabled  
**Storage Mount**: `/mnt/storage` → `/mnt/storage` (unified path)  
**Tags**: `media`

**Hardware Passthrough**:
```bash
# Intel Arc A380 GPU
lxc.cgroup2.devices.allow: c 226:0 rwm      # card0
lxc.cgroup2.devices.allow: c 226:128 rwm    # renderD128
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
```

**Installed Software**:
- FFmpeg 5.1.7 (with VA-API support)
- Intel Media Driver (VA-API working on renderD128)
- Media user (UID 1000, member of `video` and `render` groups)

**GPU Verification**:
```
vainfo: VA-API version: 1.17 (libva 2.12.0)
Driver: Intel iHD driver for Intel(R) Gen Graphics
```

**Purpose**: Hardware-accelerated transcoding using Intel Arc GPU

**Status**: ✅ Running, GPU passthrough working

---

### CT202: Analyzer

**Type**: Privileged  
**OS**: Debian  
**Network**: DHCP on vmbr0, Firewall disabled  
**Storage Mount**: `/mnt/storage` → `/mnt/storage` (unified path)  
**Tags**: `media`

**Installed Software**:
- Media analysis tools
- Media user (UID 1000)

**Purpose**: Media file analysis and validation

**Status**: ✅ Running

---

## User Configuration

### Media User (Standardized)

**On Host**:
- **Username**: `media`
- **UID**: 1000
- **GID**: 1000
- **Groups**: `media`, `cdrom`, `video`, `render`
- **Home**: `/home/media`

**In Containers**:

| Container | UID | GID | Groups |
|-----------|-----|-----|--------|
| CT200 (ripper-new) | 1000 | 1000 | `media`, `cdrom` |
| CT201 (transcoder-new) | 1000 | 1000 | `media`, `video`, `render` |
| CT202 (analyzer) | 1000 | 1000 | `media` |

**Permissions Strategy**: 
- All containers use privileged mode for hardware access
- Unified UID/GID 1000 across host and containers
- Storage mounted with consistent paths (`/mnt/storage`)

---

## Network Configuration

### Host Network

**Primary Bridge**: `vmbr0`
- **Type**: Linux bridge
- **Address**: 192.168.1.56/24
- **Method**: Static
- **Bridge Ports**: `eno1`

**Container Networking**: All containers use DHCP on vmbr0

### Container IP Addresses

| Container | IP Address | Hostname |
|-----------|------------|----------|
| jellyfin (101) | 192.168.1.128 | jellyfin |
| ripper-new (200) | 192.168.1.75 | ripper-new |
| transcoder-new (201) | 192.168.1.77 | transcoder-new |
| analyzer (202) | 192.168.1.72 | analyzer |

**DHCP Server**: Managed by router (not on Proxmox host)

---

## Installed Software (Host)

### Key Packages

- **MergerFS**: `2.40.2~debian-bookworm`
- **Graphics Drivers**: `i915` module loaded (Intel integrated)
- **LXC**: `6.0.0-1`
- **Proxmox Kernel**: `6.8.12-10-pve`

### Notable Proxmox Components

- `pve-container`: 5.3.3
- `qemu-server`: 8.4.4
- `proxmox-backup-client`: 3.4.7-1
- `ceph-fuse`: 17.2.7-pve3 (installed but not in use)

---

## Device Passthrough Configuration

### Intel Arc A380 GPU

**Host Devices**:
- `/dev/dri/card1` (Intel Arc card)
- `/dev/dri/renderD128` (Intel Arc render node)

**Groups**: `video` (226), `render` (104)

**Container Usage**: CT201 (transcoder-new)

**Verification Command**:
```bash
pct exec 201 -- vainfo --display drm --device /dev/dri/renderD128
```

**Status**: ✅ Working (VA-API 1.17, Intel iHD driver)

### Optical Drive (Blu-ray)

**Host Devices**:
- `/dev/sr0` (block device, major 11, minor 0)
- `/dev/sg4` (SCSI generic, major 21, minor 4)

**Group**: `cdrom` (24)

**Container Usage**: CT200 (ripper-new)

**Verification Command**:
```bash
pct exec 200 -- makemkvcon info disc:0
```

**Status**: ✅ Working (MakeMKV can read discs)

---

## Current Operational Status

### Active Workflows

1. **Ripping**: CT200 (ripper-new) with optical drive passthrough ✅
2. **Transcoding**: CT201 (transcoder-new) with Intel Arc GPU ✅
3. **Media Serving**: CT101 (jellyfin) ✅
4. **Analysis**: CT202 (analyzer) ✅

### Pending Migrations

- [ ] Migrate CT100 (old ripper) configuration to IaC
- [ ] Migrate CT102 (old transcoder) configuration to IaC
- [ ] Document and archive old containers
- [ ] Remove old containers after IaC validation

### Known Issues

1. **Container Networking**: Containers sometimes need manual network activation after creation (fixed with proper fstab in container)
2. **Unprivileged Containers**: Permission issues with MergerFS write access (why we use privileged)
3. **GPU Driver**: Intel Arc requires `i915` module, `intel-media-va-driver` package not installed on host (but works in container)

---

## Infrastructure as Code Status

### Current State

**Manual Management**:
- ✅ Host configuration (MergerFS, storage, network)
- ✅ Active production containers (CT200, CT201, CT202)
- ✅ Legacy containers (CT100, CT102)

**IaC Ready**:
- [ ] Terraform configurations
- [ ] Ansible playbooks
- [ ] Container definitions
- [ ] Device passthrough automation

**Next Steps**:
1. Create Terraform definitions for new containers (200, 201, 202)
2. Create Ansible roles for MakeMKV, FFmpeg, GPU passthrough
3. Test import workflow with test container (CTID 199)
4. Document disaster recovery procedure

---

## Reference Information

### Important File Locations

**Host**:
- LXC Configs: `/etc/pve/lxc/<CTID>.conf`
- fstab: `/etc/fstab`
- MergerFS Mount: `/mnt/storage`

**Media Pipeline**:
- Scripts: `/home/cuiv/dev/homelab-notes/scripts/media/`
- Staging: `/mnt/storage/media/staging/`
- Library: `/mnt/storage/media/{movies,tv}/`

**Documentation**:
- IaC Strategy: `/home/cuiv/dev/homelab-notes/docs/reference/homelab-iac-strategy.md`
- This Document: `/home/cuiv/dev/homelab-notes/docs/reference/current-state.md`

### Quick Commands

```bash
# SSH to host
ssh homelab

# List containers
pct list

# Enter container
pct enter <CTID>

# Check storage
df -h /mnt/storage

# Check GPU in transcoder
pct exec 201 -- vainfo --display drm --device /dev/dri/renderD128

# Check optical drive in ripper
pct exec 200 -- ls -la /dev/sr0 /dev/sg4
```

---

**Document Status**: ✅ Current as of 2025-11-11  
**Data Source**: Live SSH inspection of homelab system  
**Maintenance**: Update when infrastructure changes occur
