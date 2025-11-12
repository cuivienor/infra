# CT305: Jellyfin Media Server

**Status**: ✅ Production Ready  
**Deployed**: 2025-11-11  
**Management**: IaC (Terraform + Ansible)

---

## Overview

High-priority media streaming server with dual GPU hardware transcoding support. Optimized for 4K HDR content with tone-mapping and modern codec support (AV1, HEVC).

---

## Container Specifications

| Property | Value |
|----------|-------|
| **CTID** | 305 |
| **Hostname** | jellyfin |
| **IP Address** | 192.168.1.85/24 (static) |
| **Type** | Privileged (for GPU passthrough) |
| **OS** | Debian 12 (bookworm) |
| **Template** | debian-12-standard_12.7-1_amd64.tar.zst |

---

## Resource Allocation

| Resource | Allocation | Rationale |
|----------|------------|-----------|
| **CPU Cores** | 4 | Highest priority - handles multiple streams + transcoding |
| **RAM** | 8GB + 4GB swap | Large metadata database, caching, multiple streams |
| **Disk** | 32GB | 4x old CT101 - room for metadata, cache, thumbnails, logs |
| **Priority** | Highest | Primary user-facing service |

**Comparison to old CT101:**
- Disk: 32GB vs 8GB (100% full on old one)
- CPU: 4 cores vs 2 cores
- RAM: 8GB vs 6GB
- GPU: Correct Intel Arc vs wrong NVIDIA card

---

## GPU Configuration

### Intel Arc A380 (Primary)
- **Device**: `/dev/dri/card1` + `/dev/dri/renderD129`
- **Purpose**: Primary transcoding GPU
- **API**: VA-API 1.17 (Intel iHD driver)
- **Codecs Supported**:
  - H.264 encode/decode (hardware)
  - HEVC encode/decode (including 10-bit HDR)
  - VP9 encode/decode
  - **AV1 encode/decode** (rare GPU capability!)
  - MPEG-2, JPEG
- **Status**: ✅ Working perfectly
- **Low Power Mode**: Enabled for efficiency

### NVIDIA GTX 1080 (Secondary/Ready)
- **Device**: `/dev/dri/card0` + `/dev/dri/renderD128`
- **Purpose**: Backup/fallback for NVENC
- **Status**: Device present, drivers not installed on host
- **Future Use**: Can enable NVENC if needed for specific clients

### Jellyfin User Groups
- `video` (GID 44) - GPU access
- `render` (GID 104) - Render device access

---

## Storage Mounts

### Media Library (New Organized Structure)
```
Host: /mnt/storage/media/library
Container: /media/library
├── movies/     (empty, ready for organized content)
└── tv/         (empty, ready for organized content)
```

### Legacy Media (Transition Period)
```
Host: /mnt/storage/media
Container: /media/legacy
├── movies/     (existing media collection)
├── tv/         (existing TV shows)
├── audiobooks/
├── e-books/
└── staging/    (media pipeline)
```

**Access**: Jellyfin can access both library structures during transition period.

---

## Hardware Acceleration Configuration

### Encoding Settings (`/etc/jellyfin/encoding.xml`)

```xml
<HardwareAccelerationType>vaapi</HardwareAccelerationType>
<VaapiDevice>/dev/dri/renderD129</VaapiDevice>
<EnableHardwareEncoding>true</EnableHardwareEncoding>
<AllowHevcEncoding>true</AllowHevcEncoding>
<AllowAv1Encoding>true</AllowAv1Encoding>
<EnableTonemapping>true</EnableTonemapping>
<EnableVppTonemapping>true</EnableVppTonemapping>
<EnableIntelLowPowerH264HwEncoder>true</EnableIntelLowPowerH264HwEncoder>
<EnableIntelLowPowerHevcHwEncoder>true</EnableIntelLowPowerHevcHwEncoder>
```

### Available Encoders
- `h264_vaapi` - H.264 hardware encoding
- `hevc_vaapi` - HEVC/H.265 hardware encoding
- `av1_vaapi` - **AV1 hardware encoding** (Intel Arc exclusive!)
- `vp9_vaapi` - VP9 hardware encoding
- Plus software fallbacks for all codecs

### Performance Expectations
- **4K HEVC → 1080p H.264**: 4-8 simultaneous streams
- **4K HDR → 1080p SDR** (with tone-mapping): 2-4 streams
- **Power efficiency**: Intel Arc is very power-efficient

---

## Network Configuration

| Service | Port | Protocol | Access |
|---------|------|----------|--------|
| **Web UI** | 8096 | HTTP | LAN |
| **HTTPS** | 8920 | HTTPS | Optional |
| **Service Discovery** | 1900, 7359 | UDP | LAN |

**Web Interface**: http://192.168.1.85:8096

---

## IaC Management

### Terraform Configuration
**File**: `terraform/ct305-jellyfin.tf`

```hcl
resource "proxmox_virtual_environment_container" "jellyfin" {
  vm_id = 305
  # ... 4 cores, 8GB RAM, 32GB disk, dual mounts
}
```

### Ansible Roles

**Primary Role**: `ansible/roles/jellyfin/`
- Installs Jellyfin from official repository
- Configures hardware acceleration
- Sets up media user and groups
- Deploys optimized encoding.xml

**GPU Role**: `ansible/roles/dual_gpu_passthrough/`
- Passes both Intel Arc and NVIDIA to container
- Configures cgroup device permissions
- Sets up /dev/dri mount

### Deployment Playbook
**File**: `ansible/playbooks/ct305-jellyfin.yml`

```bash
# Deploy/update Jellyfin
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/ct305-jellyfin.yml
```

---

## Updates

### Current Version
- **Jellyfin Server**: 10.11.2 (latest stable)
- **Jellyfin FFmpeg**: 7.1.2-4
- **Repository**: https://repo.jellyfin.org/debian (official)

### Update Process
```bash
# Just re-run the playbook
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/ct305-jellyfin.yml
```

Since `jellyfin_version: "latest"` is set in defaults, the playbook will automatically update to the latest version from the official repository.

### Stay Informed
- **GitHub Releases**: https://github.com/jellyfin/jellyfin/releases
- **Watch Releases**: Enable notifications on GitHub repository

---

## Usage

### Initial Setup
1. Navigate to: http://192.168.1.85:8096
2. Complete setup wizard
3. Create admin account
4. Add library paths:
   - **Movies**: `/media/legacy/movies` (existing content)
   - **TV Shows**: `/media/legacy/tv` (existing content)
   - **Future**: `/media/library/movies`, `/media/library/tv`

### Verify Hardware Acceleration
1. Go to **Dashboard → Playback → Transcoding**
2. Confirm settings:
   - Hardware acceleration: **VA-API** ✓
   - VA-API Device: `/dev/dri/renderD129` ✓
   - Enable hardware encoding ✓
   - Allow HEVC encoding ✓
   - Intel Low Power encoders ✓
   - **Allow AV1 encoding ✓**

### Test Transcoding
1. Play a 4K HEVC video
2. Force transcode (change quality/resolution)
3. Check **Dashboard → Activity**
4. Look for "Transcode (hw)" indicator
5. Monitor: `ssh homelab "pct exec 305 -- intel_gpu_top"` (if intel-gpu-tools installed)

---

## Monitoring & Logs

### Service Status
```bash
ssh homelab "pct exec 305 -- systemctl status jellyfin"
```

### Real-time Logs
```bash
ssh homelab "pct exec 305 -- journalctl -u jellyfin -f"
```

### Application Logs
```bash
ssh homelab "pct exec 305 -- tail -f /var/log/jellyfin/jellyfin*.log"
```

### GPU Verification
```bash
# Check GPU access
ssh homelab "pct exec 305 -- ls -la /dev/dri/"

# Test VA-API
ssh homelab "pct exec 305 -- vainfo --display drm --device /dev/dri/card1"
```

### Resource Usage
```bash
ssh homelab "pct exec 305 -- htop"
ssh homelab "pct exec 305 -- df -h"
```

---

## Troubleshooting

### Hardware Transcoding Not Working

1. **Check GPU devices present:**
   ```bash
   ssh homelab "pct exec 305 -- ls -la /dev/dri/"
   ```
   Should show card0, card1, renderD128, renderD129

2. **Verify jellyfin user groups:**
   ```bash
   ssh homelab "pct exec 305 -- id jellyfin"
   ```
   Should include `video` and `render` groups

3. **Test VA-API directly:**
   ```bash
   ssh homelab "pct exec 305 -- vainfo --display drm --device /dev/dri/card1"
   ```
   Should show Intel Arc codecs

4. **Check encoding.xml:**
   ```bash
   ssh homelab "pct exec 305 -- cat /etc/jellyfin/encoding.xml | grep VaapiDevice"
   ```
   Should show `/dev/dri/renderD129`

5. **Restart Jellyfin:**
   ```bash
   ssh homelab "pct exec 305 -- systemctl restart jellyfin"
   ```

### Service Won't Start
```bash
# Check logs for errors
ssh homelab "pct exec 305 -- journalctl -u jellyfin -n 100"

# Check permissions
ssh homelab "pct exec 305 -- ls -la /etc/jellyfin /var/lib/jellyfin"

# Verify configuration
ssh homelab "pct exec 305 -- jellyfin --version"
```

---

## Migration from CT101

### Current Status
- **CT101**: Old Jellyfin (8GB disk, 100% full, wrong GPU)
- **CT305**: New Jellyfin (fresh install, correct GPU, 4x disk space)

### Migration Strategy
1. **Phase 1**: Test CT305 functionality
   - Add libraries (legacy media paths)
   - Test playback and transcoding
   - Verify hardware acceleration
   - Test with multiple clients

2. **Phase 2**: Transition period (optional)
   - Run both containers in parallel
   - Migrate user preferences if needed
   - Update bookmarks/clients to new IP

3. **Phase 3**: Decommission CT101
   - Stop CT101 service
   - Keep container for 1-2 weeks as backup
   - Destroy after confirming CT305 stability

### Data NOT Migrated (Intentional)
- Watch history (fresh start)
- User preferences (reconfigure)
- Metadata/artwork (will re-download)

**Rationale**: Fresh install ensures no configuration baggage, properly configured from start.

---

## Performance Optimizations

- ✅ Intel Arc Low Power encoders enabled
- ✅ 4 CPU cores for parallel operations
- ✅ 8GB RAM for large metadata cache
- ✅ 32GB disk for transcoding cache
- ✅ Tone-mapping hardware accelerated
- ✅ Multiple codec support (H.264, HEVC, AV1, VP9)
- ✅ Read-ahead caching for smooth playback

---

## Security Considerations

- **Container Type**: Privileged (required for GPU passthrough)
- **Media Access**: Read-only to media files (Jellyfin doesn't write to media)
- **Write Access**: Only to /etc/jellyfin and /var/lib/jellyfin
- **Network**: LAN only (no external access configured)

---

## Tags
- `media`
- `iac`
- `jellyfin`
- `high-priority`

---

## Related Documentation
- [Jellyfin Official Docs](https://jellyfin.org/docs/)
- [Intel Arc Transcoding Guide](https://jellyfin.org/docs/general/administration/hardware-acceleration/intel/)
- [VA-API Setup](https://jellyfin.org/docs/general/administration/hardware-acceleration/intel/#configure-on-linux-host)

---

**Last Updated**: 2025-11-11
