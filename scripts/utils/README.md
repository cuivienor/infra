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

## Quick Reference

**Monitor Jellyfin streams:**
```bash
cd /home/cuiv/dev/homelab-notes/scripts/utils
./monitor-jellyfin.sh
```

**Check script status:**
```bash
ls -la /home/cuiv/dev/homelab-notes/scripts/utils/*.sh
```
