# Legacy Container Cleanup Summary

**Date**: 2025-11-11
**Action**: Decommissioned CT100 and CT102

---

## Containers Removed

### CT100 (ripper - old)
- **Status**: Stopped, deleted
- **Purpose**: Original MakeMKV ripper container
- **Replaced by**: CT200 (ripper-new)
- **Storage**: 8GB LVM volume (vm-100-disk-1) - deleted
- **Config backup**: `ct100-config-backup.conf`

**Configuration highlights**:
- Privileged container
- Optical drive passthrough: `/dev/sr0`, `/dev/sg4`
- Storage mount: `/mnt/storage` → `/data`
- 4 cores, 1GB RAM

### CT102 (transcoder - old)
- **Status**: Stopped, deleted
- **Purpose**: Original FFmpeg transcoder container
- **Replaced by**: CT201 (transcoder-new)
- **Storage**: 20GB LVM volume (vm-102-disk-0) - deleted
- **Config backup**: `ct102-config-backup.conf`

**Configuration highlights**:
- Unprivileged container (with ID mapping)
- Intel Arc GPU passthrough: `/dev/dri/card0`, `/dev/dri/renderD128`
- Storage mount: `/mnt/storage/media` → `/mnt/media`
- 8 cores, 8GB RAM

---

## Cleanup Process

1. **Verification**: Confirmed both containers were stopped
2. **Backup**: Saved LXC configurations to this directory
3. **Data check**: Verified no unique data in container root filesystems
4. **Deletion**: Ran `pct destroy <CTID> --purge` for both containers
5. **Verification**: Confirmed LVM volumes and configs removed
6. **Documentation**: Updated AGENTS.md and CURRENT-STATUS.md

---

## Why They Were Removed

**CT200 and CT201 are superior replacements**:
- Better naming convention (`ripper-new`, `transcoder-new`)
- More recent configurations
- Already in active use
- Part of the new media pipeline v2 implementation

**No data loss**:
- All media processing happens in `/mnt/storage` (shared host storage)
- Container root filesystems only contained OS and applications
- Configurations backed up for reference

---

## Current Active Media Containers

### Production Containers (Manual)
- **CT200 ripper-new** (192.168.1.75) - MakeMKV, optical drive
- **CT201 transcoder-new** (192.168.1.77) - FFmpeg, Intel Arc GPU
- **CT202 analyzer** (192.168.1.72) - Media analysis tools
- **CT101 jellyfin** (192.168.1.128) - Media server

### IaC Containers (Future Migration)
These containers will eventually be imported into Terraform/Ansible for full IaC management.

---

## Commands Used

```bash
# List containers
ssh homelab "pct list"

# View configs
ssh homelab "cat /etc/pve/lxc/100.conf"
ssh homelab "cat /etc/pve/lxc/102.conf"

# Check for data
ssh homelab "pct mount 100 && du -sh /var/lib/lxc/100/rootfs/* && pct unmount 100"
ssh homelab "pct mount 102 && du -sh /var/lib/lxc/102/rootfs/* && pct unmount 102"

# Delete with storage purge
ssh homelab "pct destroy 100 --purge"
ssh homelab "pct destroy 102 --purge"

# Verify deletion
ssh homelab "pct list"
ssh homelab "lvs | grep -E 'vm-100|vm-102'"
```

---

## Next Steps

**Phase 2 Container Migration**:
- [ ] Import CT200 to Terraform
- [ ] Import CT201 to Terraform
- [ ] Import CT202 to Terraform
- [ ] Create device passthrough Ansible role
- [ ] Document migration process

**Goal**: Full IaC management of all containers

---

**Cleanup completed**: 2025-11-11
**Verified by**: Automated process with configuration backups
**Status**: ✅ Successfully removed with no issues
