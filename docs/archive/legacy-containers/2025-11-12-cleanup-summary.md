# Container Cleanup - November 2025

**Date**: 2025-11-12
**Action**: Removed old manual containers, fully migrated to IaC

---

## Containers Removed

### CT101 (jellyfin - old)
- **Status**: Stopped, deleted
- **Purpose**: Original Jellyfin media server (unprivileged)
- **Replaced by**: CT305 (jellyfin IaC)
- **Storage**: 8GB LVM volume (vm-101-disk-0) - deleted
- **Config backup**: `ct101-config-backup.conf`
- **IP**: 192.168.1.128

### CT200 (ripper-new)
- **Status**: Stopped, deleted
- **Purpose**: MakeMKV ripper with optical drive passthrough
- **Replaced by**: CT302 (ripper IaC)
- **Storage**: 8GB LVM volume (vm-200-disk-0) - deleted
- **Config backup**: `ct200-config-backup.conf`
- **IP**: 192.168.1.75

### CT201 (transcoder-new)
- **Status**: Stopped, deleted
- **Purpose**: FFmpeg transcoder with Intel Arc GPU passthrough
- **Replaced by**: CT304 (transcoder IaC)
- **Storage**: 20GB LVM volume (vm-201-disk-0) - deleted
- **Config backup**: `ct201-config-backup.conf`
- **IP**: 192.168.1.77

### CT202 (analyzer)
- **Status**: Stopped, deleted
- **Purpose**: Media analysis tools
- **Replaced by**: CT303 (analyzer IaC)
- **Storage**: 12GB LVM volume (vm-202-disk-0) - deleted
- **Config backup**: `ct202-config-backup.conf`
- **IP**: 192.168.1.72

---

## Cleanup Process

1. **Verification**: Confirmed new IaC containers (300-305) working correctly
2. **Backup**: Saved LXC configurations to archive directory
3. **Stop**: Stopped all old containers (CT101, CT200, CT201, CT202)
4. **Delete**: Ran `pct destroy <CTID> --purge` for each container
5. **Verification**: Confirmed LVM volumes and configs removed
6. **Documentation**: Updated all reference documents

---

## Storage Reclaimed

| Container | Disk Size | Status |
|-----------|-----------|--------|
| CT101 | 8GB | ✅ Freed |
| CT200 | 8GB | ✅ Freed |
| CT201 | 20GB | ✅ Freed |
| CT202 | 12GB | ✅ Freed |
| **Total** | **48GB** | **✅ Freed** |

---

## Final Active Containers (All IaC)

| CTID | Name | IP | Purpose | Resources |
|------|------|-----|---------|-----------|
| 300 | backup | 192.168.1.58 | Restic + Backrest UI | 2 cores, 4GB RAM, 20GB disk |
| 301 | samba | 192.168.1.82 | Samba file server | 2 cores, 2GB RAM, 8GB disk |
| 302 | ripper | 192.168.1.70 | MakeMKV + optical drive | 2 cores, 4GB RAM, 8GB disk |
| 303 | analyzer | 192.168.1.73 | Media analysis tools | 2 cores, 4GB RAM, 12GB disk |
| 304 | transcoder | 192.168.1.77 | FFmpeg + Intel Arc GPU | 4 cores, 8GB RAM, 20GB disk |
| 305 | jellyfin | 192.168.1.85 | Media server + dual GPU | 4 cores, 8GB RAM, 32GB disk |

---

## Benefits Achieved

✅ **Full IaC Coverage**: All containers managed by Terraform + Ansible
✅ **Consistent Naming**: All containers follow 300-series naming convention
✅ **Security Enhancement**: Restricted storage mounts (ripper only accesses staging)
✅ **Reproducibility**: Complete disaster recovery capability
✅ **Storage Efficiency**: 48GB disk space reclaimed
✅ **Clarity**: No duplicate or legacy containers

---

## IP Address Changes

**Important**: Update any scripts or bookmarks with new IPs:

| Service | Old IP | New IP | Notes |
|---------|--------|--------|-------|
| Jellyfin | 192.168.1.128 | 192.168.1.85 | Web UI + streaming |
| Ripper | 192.168.1.75 | 192.168.1.70 | MakeMKV access |
| Transcoder | 192.168.1.77 | 192.168.1.77 | No change (same IP) |
| Analyzer | 192.168.1.72 | 192.168.1.73 | Analysis tools |

---

## Commands Used

```bash
# Backup configs
ssh homelab "cat /etc/pve/lxc/101.conf" > ct101-config-backup.conf
ssh homelab "cat /etc/pve/lxc/200.conf" > ct200-config-backup.conf
ssh homelab "cat /etc/pve/lxc/201.conf" > ct201-config-backup.conf
ssh homelab "cat /etc/pve/lxc/202.conf" > ct202-config-backup.conf

# Stop containers
ssh homelab "pct stop 101 && pct stop 200 && pct stop 201 && pct stop 202"

# Delete with storage purge
ssh homelab "pct destroy 101 --purge"
ssh homelab "pct destroy 200 --purge"
ssh homelab "pct destroy 201 --purge"
ssh homelab "pct destroy 202 --purge"

# Verify deletion
ssh homelab "pct list"
ssh homelab "lvs | grep -E 'vm-10[012]|vm-20[012]'"
```

---

## Next Steps

- [x] All legacy containers removed
- [ ] Update media pipeline scripts with new IPs if needed
- [ ] Test end-to-end media workflow with new containers
- [ ] Monitor new containers for stability
- [ ] Document any issues or optimizations

---

**Cleanup completed**: 2025-11-12
**Status**: ✅ Successfully migrated to full IaC environment
**No data loss**: All media processing happens in shared `/mnt/storage`
