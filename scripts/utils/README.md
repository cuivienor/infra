# Utility Scripts

Helper scripts for homelab management and monitoring.

---

## Monitoring

### `monitor-jellyfin.sh`

Real-time monitoring of Jellyfin streaming activity.

**Usage:**
```bash
./monitor-jellyfin.sh [interval_seconds]
```

**Example:**
```bash
# Default: refresh every 5 seconds
./monitor-jellyfin.sh

# Custom: refresh every 2 seconds
./monitor-jellyfin.sh 2
```

**Shows:**
- Active transcode count
- FFmpeg process details (if transcoding)
- Intel Arc GPU usage (Video encode/decode %)
- CPU and memory usage
- Jellyfin service status

**Press Ctrl+C to exit**

---

## Infrastructure Management

### `deploy-scripts.sh`

Deploy media pipeline scripts to containers.

**Usage:**
```bash
./deploy-scripts.sh
```

Syncs scripts from repository to:
- CT302 (ripper): `/home/media/scripts/`
- CT303 (analyzer): `/home/media/scripts/`
- CT304 (transcoder): `/home/media/scripts/`

### `cleanup-backup-orphans.sh`

Clean up orphaned backup files from old container migrations.

**Usage:**
```bash
./cleanup-backup-orphans.sh
```

Removes backup files left behind after container cleanup.

### `reorganize-storage.sh`

One-time storage reorganization script (completed).

**Status**: Historical reference - storage already reorganized

---

## Quick Reference

**Monitor Jellyfin streams:**
```bash
cd /home/cuiv/dev/homelab-notes/scripts/utils
./monitor-jellyfin.sh
```

**Deploy updated scripts:**
```bash
cd /home/cuiv/dev/homelab-notes/scripts/utils
./deploy-scripts.sh
```

**Check script status:**
```bash
# All utils scripts are executable
ls -la /home/cuiv/dev/homelab-notes/scripts/utils/*.sh
```
