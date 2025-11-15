# SnapRAID Setup Review

**Date**: 2025-11-13  
**Status**: ✅ Well-configured and fully automated

---

## Summary

Your SnapRAID setup is **excellent** and follows best practices! It's fully managed by Ansible, automated with systemd timers, and configured appropriately for a media server workload.

---

## Current Configuration

### Management: ✅ Fully IaC

**Ansible Role**: `proxmox_storage`  
**Location**: `ansible/roles/proxmox_storage/`

**Configuration is managed by**:
- Ansible templates (`snapraid.conf.j2`)
- Ansible tasks (`tasks/snapraid.yml`)
- Version controlled in Git
- Deployed via `ansible/playbooks/storage.yml`

**Evidence**: Config file header says "Managed by Ansible - DO NOT EDIT MANUALLY" ✅

### SnapRAID Version

- **Current**: v12.3
- **Installed**: From source (GitHub)
- **Location**: `/usr/local/bin/snapraid`
- **Status**: Latest stable release ✅

### Array Configuration

| Component | Path | Size | Usage | Notes |
|-----------|------|------|-------|-------|
| **Parity** | `/mnt/parity` | 16.4TB | 25% (3.8TB) | WD Red Plus 18TB |
| **Data d1** | `/mnt/disk1` | 9.1TB | 43% (3.7TB) | WD Red Plus 10TB |
| **Data d2** | `/mnt/disk2` | 9.1TB | 2% (166GB) | Seagate Barracuda 10TB |
| **Data d3** | `/mnt/disk3` | 16.4TB | 5% (648GB) | WD Red Plus 18TB |

**Protection Level**: Single parity (can recover from 1 disk failure)

**Content Files** (redundancy):
- `/mnt/disk1/.snapraid.content`
- `/mnt/disk2/.snapraid.content`
- `/mnt/disk3/.snapraid.content`

✅ Content files stored on all data disks for redundancy (best practice)

### Technical Settings

```ini
block_size = 256      # Standard for large files
hashsize = 16         # 128-bit checksums (good balance)
autosave = 500        # Save state every 500 blocks
```

✅ **All appropriate for media server workload**

### Exclusions

**Correctly excludes**:
- Temporary files (`/tmp/`, `downloads/`, `*.!sync`)
- System files (`/lost+found/`)
- Container/VM data (`/lxc/`, `/images/`)
- macOS/Windows cruft (`.DS_Store`, `.Trashes`, etc.)
- Incomplete files (`*.unrecoverable`)

✅ **Smart exclusions prevent parity wasted on temporary/changing data**

---

## Automation: ✅ Excellent

### Systemd Timers (Modern, Best Practice)

**Sync Timer**: `snapraid-sync.timer`
- **Schedule**: Daily at 3:00 AM
- **Status**: ✅ Active and enabled
- **Next run**: Every day at 03:00:00
- **Service**: `snapraid-sync.service`

**Scrub Timer**: `snapraid-scrub.timer`
- **Schedule**: Weekly on Monday at 4:00 AM
- **Status**: ✅ Active and enabled
- **Next run**: Monday 04:00:00
- **Scrub percentage**: 8% of array per week
- **Service**: `snapraid-scrub.service`

**Why this is good**:
- ✅ Uses systemd timers (modern, reliable)
- ✅ NOT using cron (systemd is better for services)
- ✅ Sync runs daily (parity stays current)
- ✅ Scrub runs weekly (validates parity integrity)
- ✅ Different times to avoid conflicts
- ✅ Runs at night during low usage

### Runner Script

**Location**: `/usr/local/bin/snapraid-runner.sh`  
**Managed by**: Ansible (templated)

**Features**:
- ✅ Prevents concurrent runs (checks for existing snapraid process)
- ✅ Logs all output with timestamps
- ✅ Rotates logs (keeps 30 days)
- ✅ Handles both sync and scrub operations
- ✅ Error handling with proper exit codes

**Log Directory**: `/var/log/snapraid/`

---

## Recent Activity

### Last Sync: 2025-11-13 at 03:00 AM

**Performance**:
- **Duration**: ~65 seconds
- **Data processed**: 19.9 GB
- **Speed**: ~420 MB/s
- **CPU usage**: 6% (low impact)
- **Result**: ✅ "Everything OK"

**Wait Time Distribution** (disk bottlenecks):
- disk1: 72% (heavily used, as expected with 3.7TB)
- disk2: 0% (nearly empty)
- disk3: 2% (lightly used)
- parity: 18% (writing parity data)

This is normal and healthy!

### Last Scrub: 299 days ago ⚠️

**Issue**: From `snapraid status`:
```
The oldest block was scrubbed 299 days ago, the median 290, the newest 0.
42% of the array is not scrubbed.
```

**Analysis**:
- Your scrub timer is correctly configured (Monday 4 AM, 8% per week)
- Timer was only enabled on 2025-11-11 (when you deployed IaC)
- Previous setup didn't have automated scrubbing
- **This is expected** - you just recently automated it!

**What will happen**:
- Scrubbing 8% per week = full array scrubbed in ~12.5 weeks
- Next scrub: Monday 2025-11-17 at 04:00 AM
- After ~3 months, entire array will be validated

✅ **This will self-correct over the next few months**

---

## Best Practices Checklist

### Configuration
- ✅ Parity disk ≥ largest data disk (18TB parity, 18TB largest data)
- ✅ Content files on all data disks (3 copies)
- ✅ Excludes temporary/changing files
- ✅ Appropriate block size (256 KB for large media files)
- ✅ Managed by Ansible (Infrastructure as Code)

### Automation
- ✅ Daily sync (keeps parity current)
- ✅ Weekly scrub (validates parity integrity)
- ✅ Automated with systemd timers (not cron)
- ✅ Logging enabled
- ✅ Log rotation configured
- ✅ Prevents concurrent runs

### Operations
- ✅ Runs during low-usage hours (3-4 AM)
- ✅ Scrub percentage appropriate (8% = full scrub in ~3 months)
- ✅ Recent sync successful with no errors
- ✅ Fast sync times (~1 minute for incremental)

---

## Comparison to Perfect Media Server Recommendations

From the [Perfect Media Server SnapRAID guide](https://perfectmediaserver.com/02-tech-stack/snapraid/):

| Recommendation | Your Setup | Status |
|----------------|------------|--------|
| Use SnapRAID for mostly-static datasets | Media library | ✅ Perfect fit |
| Combine with mergerfs for pooling | Using mergerfs | ✅ Yes |
| Run parity sync regularly | Daily at 3 AM | ✅ Exceeds recommendation |
| Scrub array periodically | Weekly (8% per run) | ✅ Good cadence |
| Don't use for high-churn data | Excludes containers/VMs | ✅ Correct exclusions |
| Parity disk ≥ largest data disk | 18TB parity, 18TB max data | ✅ Meets requirement |
| Content files on multiple disks | All 3 data disks | ✅ Best practice |

**Grade**: A+ ✅

---

## Understanding Your Setup

### What SnapRAID Does

1. **Daily Sync** (3 AM):
   - Scans all data disks for changes
   - Calculates parity data for new/changed files
   - Updates parity disk
   - Saves state to content files
   - Takes: ~1-5 minutes (incremental)

2. **Weekly Scrub** (Monday 4 AM):
   - Reads 8% of array data + parity
   - Verifies checksums match (detects bitrot)
   - Reports any errors
   - Takes: ~1-2 hours (depends on data size)

3. **Protection**:
   - Can recover ANY ONE failed disk
   - Detects silent data corruption (bitrot)
   - File-level recovery (restore individual files)

### Risk Window

**Important concept**: SnapRAID has a "risk window"

- New files are NOT protected until next sync runs
- If you download a movie at 6 PM, it's unprotected until 3 AM
- If a disk fails before sync, that new file is lost

**Mitigation strategies**:
1. **Manual sync** if you add important data: `ssh homelab "snapraid sync"`
2. **Backups** for critical data (you have CT300 - Restic!)
3. **Accept the risk** for media (can re-rip/re-download)

This trade-off is why SnapRAID is perfect for media but NOT for databases!

---

## How to Use SnapRAID

### Check Status

```bash
# Overall array status
ssh root@homelab "snapraid status"

# Check timers
ssh root@homelab "systemctl list-timers snapraid-*"

# View recent logs
ssh root@homelab "ls -lh /var/log/snapraid/"
ssh root@homelab "tail /var/log/snapraid/snapraid-$(date +%Y%m%d)-*.log"
```

### Manual Operations

```bash
# Manual sync (after adding lots of new files)
ssh root@homelab "snapraid sync"

# Manual scrub (verify parity for percentage of array)
ssh root@homelab "snapraid scrub -p 15"  # 15% of array

# Full scrub (takes many hours!)
ssh root@homelab "snapraid scrub -p 100"

# Check specific file
ssh root@homelab "snapraid status /mnt/disk1/path/to/file.mkv"
```

### Recovery (Disk Failure)

```bash
# Fix ALL files on failed disk d2
ssh root@homelab "snapraid fix -d d2"

# Fix specific file
ssh root@homelab "snapraid fix -f /mnt/disk1/path/to/corrupted/file.mkv"

# Check what would be fixed (dry run)
ssh root@homelab "snapraid fix -d d2 --test"
```

### Monitoring

```bash
# Check last sync result
ssh root@homelab "journalctl -u snapraid-sync.service -n 50"

# Check last scrub result  
ssh root@homelab "journalctl -u snapraid-scrub.service -n 50"

# Watch sync in progress (if running manually)
ssh root@homelab
tail -f /var/log/snapraid/snapraid-$(date +%Y%m%d)-*.log
```

---

## Configuration Management

### Ansible Variables

**File**: `ansible/roles/proxmox_storage/defaults/main.yml`

**Key settings**:
```yaml
snapraid_version: "12.3"
snapraid_sync_enabled: true
snapraid_sync_schedule: "*-*-* 03:00:00"      # 3 AM daily
snapraid_scrub_enabled: true
snapraid_scrub_schedule: "Mon *-*-* 04:00:00"  # 4 AM Monday
snapraid_scrub_percent: 8                      # 8% per week
```

### Making Changes

**Never edit files on host directly!** Use Ansible:

```bash
# Edit Ansible variables
nano ansible/roles/proxmox_storage/defaults/main.yml

# Example: Change sync time to 2 AM
snapraid_sync_schedule: "*-*-* 02:00:00"

# Example: Scrub more aggressively (12% = ~8 weeks for full scrub)
snapraid_scrub_percent: 12

# Deploy changes
cd ansible
ansible-playbook playbooks/storage.yml --tags snapraid

# Verify on host
ssh root@homelab "systemctl list-timers snapraid-*"
```

---

## Recommendations

### Immediate Actions

None! Your setup is great. Just let it run.

### Short Term (Next Few Months)

1. **Monitor scrub progress**
   ```bash
   # Check monthly to see scrub coverage improving
   ssh root@homelab "snapraid status"
   ```
   - Currently: 42% not scrubbed (299 days old)
   - After 3 months: Should be 100% scrubbed

2. **Verify logs periodically**
   ```bash
   # Check that sync is running successfully
   ssh root@homelab "journalctl -u snapraid-sync.service --since '7 days ago'"
   ```

### Before Disk Upgrade (When You Order 18TB)

**Critical steps** (from your recovery simulation plan):

1. **Run full scrub** to validate parity
   ```bash
   ssh root@homelab "snapraid scrub -p 100"
   ```
   - Takes several hours
   - Ensures parity can actually recover data

2. **Run final sync** before simulating failure
   ```bash
   ssh root@homelab "snapraid sync"
   ```

3. **Document current state**
   ```bash
   ssh root@homelab "snapraid status" > ~/snapraid-pre-upgrade.txt
   ```

### Optional Improvements

**Email notifications** (future enhancement):
- Configure systemd services to send email on failure
- Requires SMTP setup (could use your Restic backup email config)
- Not critical, but nice to have

**Example** (future Ansible task):
```ini
[Unit]
OnFailure=status-email@%n.service
```

---

## Troubleshooting

### Sync Fails

```bash
# Check logs
ssh root@homelab "journalctl -u snapraid-sync.service -n 100"

# Common causes:
# - Disk full
# - Parity disk failure
# - File permission issues
# - Disk unmounted
```

### Scrub Reports Errors

```bash
# View errors
ssh root@homelab "snapraid status"

# Fix errors (will use parity to repair)
ssh root@homelab "snapraid fix"

# If many errors, investigate disk health
ssh root@homelab "smartctl -a /dev/sda"  # Check each disk
```

### Timer Not Running

```bash
# Check timer status
ssh root@homelab "systemctl status snapraid-sync.timer"

# If disabled, enable it
ssh root@homelab "systemctl enable --now snapraid-sync.timer"

# Check logs for why service failed
ssh root@homelab "journalctl -u snapraid-sync.service -n 50"
```

---

## Key Takeaways

### What You Have

✅ **Professional-grade setup**:
- Fully automated
- Infrastructure as Code (Ansible)
- Follows best practices
- Appropriate for media server workload
- Low maintenance

✅ **Protection**:
- Can recover from any single disk failure
- Detects and corrects bitrot
- Fast incremental syncs (daily)
- Regular integrity checks (weekly scrubs)

✅ **Performance**:
- Minimal impact (6% CPU during sync)
- Fast sync times (~1 minute daily)
- Runs during off-hours (3-4 AM)

### What It Doesn't Do

❌ **Real-time parity**: Files unprotected until next sync (acceptable trade-off)  
❌ **Multiple disk failures**: Can only recover ONE disk at a time  
❌ **Offsite backup**: This is LOCAL protection (you have CT300/Restic for offsite)  
❌ **RAID performance**: No read/write speed benefits

### Is This Good Enough?

**For a media server**: Absolutely! ✅

**Why**:
- Media files are static (low risk window)
- Can re-rip/re-download media if needed
- You have offsite backups (Restic → Backblaze B2)
- Single parity is appropriate for 3 data disks
- Daily sync keeps parity very current

**When you might need more**:
- If you had 6+ data disks → consider dual parity
- If data changes constantly → consider ZFS (real-time parity)
- If you can't tolerate ANY data loss → need different solution

---

## Related Documentation

- **IaC Management**: `docs/reference/current-state.md`
- **Storage Overview**: `docs/reference/current-state.md`
- **Disk Upgrade Plan**: `docs/plans/ideas/disk-upgrade-recovery-simulation.md`
- **Ansible Role**: `ansible/roles/proxmox_storage/`
- **Backup Setup**: `docs/reference/backup-quick-reference.md`

---

## External Resources

- [SnapRAID Official Site](https://www.snapraid.it/)
- [SnapRAID Manual](https://www.snapraid.it/manual)
- [Perfect Media Server - SnapRAID Guide](https://perfectmediaserver.com/02-tech-stack/snapraid/)
- [SnapRAID FAQ](https://www.snapraid.it/faq)

---

**Last Updated**: 2025-11-13  
**Reviewed By**: OpenCode  
**Status**: ✅ Production-ready, no changes needed

---

*"SnapRAID: Because hard drives are cheap, but your data isn't."*
