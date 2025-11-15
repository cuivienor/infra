# System Snapshot - Dynamic State

**Generated**: 2025-11-11  
**Purpose**: Track current running state and changes over time

---

## Quick Status Overview

### Host
- **Status**: ✅ Online
- **Load**: Low (2.2G / 32G RAM used)
- **Storage**: 13% used (4.1T / 35T)

### Active Containers

| CTID | Name | Status | IP | Purpose |
|------|------|--------|-----|---------|
| 101 | jellyfin | ✅ Running | 192.168.1.128 | Media server |
| 200 | ripper-new | ✅ Running | 192.168.1.75 | Blu-ray ripping |
| 201 | transcoder-new | ✅ Running | 192.168.1.77 | Video transcoding |
| 202 | analyzer | ✅ Running | 192.168.1.72 | Media analysis |

### Stopped Containers (Legacy)

| CTID | Name | Status | Notes |
|------|------|--------|-------|
| 100 | ripper | ⏸️ Stopped | Being replaced by CT200 |
| 102 | transcoder | ⏸️ Stopped | Being replaced by CT201 |

---

## Recent Changes

### 2025-11-11 (Evening)
- ✅ **MergerFS Distribution Fixed**: Changed policy from `mfs` to `eppfrd`
- ✅ **Directory Structure Replicated**: All directories from disk1 copied to disk2/disk3
- ✅ **Tested Distribution**: Verified new files now spread across all disks
- ✅ **Updated Ansible Config**: Changed `ansible/roles/proxmox_storage/defaults/main.yml`
- 📊 **Result**: New files now auto-distribute to disk2/disk3 (99% free) instead of disk1 (48% full)

### 2025-11-11 (Morning)
- ✅ Repository reorganized for IaC work
- ✅ Created comprehensive documentation structure
- ✅ Inspected live system and documented current state
- 📋 Ready to begin Terraform/Ansible implementation

### Previous
- ✅ CT200 (ripper-new) deployed with optical drive passthrough
- ✅ CT201 (transcoder-new) deployed with Intel Arc GPU passthrough
- ✅ CT202 (analyzer) deployed for media analysis
- ✅ Unified media user (UID 1000) across all containers
- ✅ Standardized storage mount path (`/mnt/storage`)

---

## Current Tasks

### In Progress
- [ ] Create Terraform configuration for test container
- [ ] Create Ansible playbooks for container configuration
- [ ] Document device passthrough automation

### Blocked
- None

### On Hold
- CT100, CT102 decommission (waiting for IaC validation)

---

## Hardware Status

### GPU (Intel Arc A380)
- **Status**: ✅ Working
- **Used By**: CT201 (transcoder-new)
- **Device**: `/dev/dri/renderD128`
- **Driver**: Intel iHD (VA-API 1.17)

### Optical Drive
- **Status**: ✅ Working
- **Used By**: CT200 (ripper-new)
- **Devices**: `/dev/sr0`, `/dev/sg4`

### Storage (MergerFS)
- **Status**: ✅ Healthy
- **Usage**: 4.1T / 35T (13%)
- **Distribution**: ✅ Balanced (updated 2025-11-11)
- **Policy**: `eppfrd` (automatic distribution to emptier disks)
- **Disks**:
  - disk1: 48% (4.1T/9.1T) - Legacy data (new files avoid)
  - disk2: 1% (470M/9.1T) - Active (receiving new files)
  - disk3: 1% (24G/17T) - Active (receiving new files)
  - parity: 20% (3.1T/17T)

---

## Storage Trends

### Media Library Growth

| Date | Total Used | Movies | TV | Notes |
|------|------------|--------|-----|-------|
| 2025-11-11 | 4.1T | (TBD) | (TBD) | Current state |

*Track this over time to monitor growth*

---

## Container Resource Usage

| CTID | Name | RAM Allocated | RAM Used | CPU Usage | Notes |
|------|------|---------------|----------|-----------|-------|
| 101 | jellyfin | 6 GB | (check) | Low | Streaming server |
| 200 | ripper-new | 4 GB | (check) | Variable | High during ripping |
| 201 | transcoder-new | 8 GB | (check) | Variable | High during transcode |
| 202 | analyzer | 4 GB | (check) | Low | Occasional use |

*Run `pct status <CTID>` to get live stats*

---

## Network Inventory

### DHCP Assignments

| Device | MAC | IP | Hostname |
|--------|-----|-----|----------|
| Host | (unknown) | 192.168.1.56 | homelab |
| CT101 | BC:24:11:2A:04:77 | 192.168.1.128 | jellyfin |
| CT200 | BC:24:11:45:04:26 | 192.168.1.75 | ripper-new |
| CT201 | BC:24:11:67:B5:18 | 192.168.1.77 | transcoder-new |
| CT202 | BC:24:11:00:42:94 | 192.168.1.72 | analyzer |

---

## Pending Actions

### Short Term
1. Create terraform test container (CTID 199)
2. Write Ansible common role
3. Test IaC workflow

### Medium Term
1. Import CT200, CT201, CT202 to Terraform state
2. Create Ansible roles for MakeMKV, FFmpeg
3. Automate device passthrough

### Long Term
1. Decommission CT100, CT102
2. Full disaster recovery test
3. Backup automation

---

## Issues to Track

### Active Issues
- None currently

### Resolved
- ✅ Unprivileged container write permissions (switched to privileged)
- ✅ GPU passthrough complexity (simplified with privileged containers)
- ✅ Inconsistent storage paths (unified to `/mnt/storage`)

---

## System Health Checks

### Last Run: 2025-11-11

```bash
# Storage health
✅ MergerFS mounted and accessible
✅ All data disks mounted
✅ Parity disk healthy

# Container health  
✅ All production containers running
✅ Network connectivity working
✅ Device passthrough functional

# Hardware health
✅ GPU accessible in CT201
✅ Optical drive accessible in CT200
✅ System temperature normal
```

---

## Notes

### Infrastructure Evolution

**Phase 1**: Manual container creation (completed)
- Created CT200, CT201, CT202 manually
- Configured device passthrough manually
- Tested and validated workflows

**Phase 2**: IaC Implementation (in progress)
- Reorganized repository structure ✅
- Documented current state ✅
- Next: Create Terraform configs

**Phase 3**: Migration & Testing (upcoming)
- Import existing containers to Terraform
- Automate configuration with Ansible
- Test disaster recovery

**Phase 4**: Production (future)
- Full IaC management
- Automated deployments
- Continuous documentation

---

## Quick Reference Commands

### Check Container Status
```bash
ssh homelab "pct list"
```

### Check Storage Usage
```bash
ssh homelab "df -h /mnt/storage"
```

### Check GPU Status
```bash
ssh homelab "pct exec 201 -- vainfo --display drm --device /dev/dri/renderD128 2>&1 | head -10"
```

### Check Optical Drive
```bash
ssh homelab "pct exec 200 -- ls -la /dev/sr0 /dev/sg4"
```

### Get Container IP
```bash
ssh homelab "pct exec <CTID> -- hostname -I"
```

---

**Update Frequency**: As needed when state changes  
**Related**: See `docs/reference/current-state.md` for static configuration details
