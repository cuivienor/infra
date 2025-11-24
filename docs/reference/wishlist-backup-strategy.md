# Wishlist Backup Strategy

**Container:** CT307 (192.168.1.186)
**Data Location:** Container disk (not /mnt/storage)
**Created:** 2025-11-24

---

## Data to Backup

Wishlist stores critical data in two locations on the container disk:

1. **SQLite Database**: `/opt/wishlist/data/prod.db`
   - Contains all user accounts, wishlists, gift items, claims, and preferences
   - Critical data that must be backed up regularly

2. **User Uploads**: `/opt/wishlist/uploads/`
   - User-uploaded gift images and attachments
   - Should be backed up to prevent data loss

**Estimated Data Size**: Small (<1GB initially, grows with usage)

---

## Backup Approach

### Primary Strategy: Manual Backup Procedures

Unlike media containers that can rely on restic backups of `/mnt/storage`, wishlist data is stored on the container disk and requires container-specific backup procedures.

**Decision Rationale:**
- Wishlist is a low-volume personal application (not production-critical)
- Data size is small and manageable for manual backups
- Container disk data is not automatically included in existing restic backup policies
- Proxmox provides built-in container backup via vzdump as a safety net
- Manual procedures are simpler and more transparent for this use case

### Backup Frequency Recommendations

- **Before updates**: Always backup before pulling new code or database migrations
- **Weekly**: Manual backup during regular maintenance window
- **On-demand**: Before any risky operations (database changes, testing, etc.)

---

## Manual Backup Procedures

### Create Backup

```bash
# Method 1: Combined tar archive (recommended)
ssh root@192.168.1.186 "tar czf /tmp/wishlist-backup-$(date +%Y%m%d).tar.gz /opt/wishlist/data /opt/wishlist/uploads"
scp root@192.168.1.186:/tmp/wishlist-backup-$(date +%Y%m%d).tar.gz ~/backups/
ssh root@192.168.1.186 "rm /tmp/wishlist-backup-$(date +%Y%m%d).tar.gz"

# Method 2: Database only (quick backup before updates)
ssh root@192.168.1.186 "cp /opt/wishlist/data/prod.db /opt/wishlist/data/prod.db.backup-$(date +%Y%m%d)"
```

### Restore from Backup

```bash
# Stop the service
ssh root@192.168.1.186 "systemctl stop wishlist"

# Restore from tar archive
scp ~/backups/wishlist-backup-20251124.tar.gz root@192.168.1.186:/tmp/
ssh root@192.168.1.186 "tar xzf /tmp/wishlist-backup-20251124.tar.gz -C /"

# Fix permissions
ssh root@192.168.1.186 "chown -R wishlist:wishlist /opt/wishlist/data /opt/wishlist/uploads"

# Restart service
ssh root@192.168.1.186 "systemctl start wishlist"
```

### Verify Backup Integrity

```bash
# Check backup exists and size
ls -lh ~/backups/wishlist-backup-*.tar.gz

# Test extraction without overwriting
ssh root@192.168.1.186 "tar tzf /tmp/wishlist-backup-20251124.tar.gz | head -20"

# Check database is valid
ssh root@192.168.1.186 "sqlite3 /opt/wishlist/data/prod.db 'PRAGMA integrity_check;'"
```

---

## Alternative: Proxmox Container Backup (Safety Net)

Proxmox provides built-in container backup capabilities via `vzdump`. This can serve as a disaster recovery option.

### Create Container Backup

```bash
# From Proxmox host
ssh cuiv@homelab "sudo vzdump 307 --mode snapshot --compress zstd --storage local"
```

This creates a full container backup including:
- Root filesystem
- All data in `/opt/wishlist/`
- System configuration
- Installed packages

**Storage Location**: `/var/lib/vz/dump/` on Proxmox host

**Pros:**
- Complete container state preservation
- Easy full restore via Proxmox UI
- Includes all system configuration

**Cons:**
- Large backup size (includes entire container, not just data)
- Not included in existing Backblaze B2 backup workflow
- Slower to create and restore than data-only backups

### Restore Container from Proxmox Backup

```bash
# Via Proxmox web UI:
# 1. Navigate to local storage -> Backups
# 2. Select wishlist backup
# 3. Click "Restore"
# 4. Configure CTID (use 307 to replace existing, or new CTID for testing)

# Via CLI:
ssh cuiv@homelab "sudo pct restore 307 /var/lib/vz/dump/vzdump-lxc-307-*.tar.zst --force"
```

---

## Off-site Backup Considerations

Currently, wishlist data is NOT automatically backed up off-site to Backblaze B2. The existing restic backup only covers `/mnt/storage`, not container disks.

### Options for Off-site Backup

**Option A: Copy backups to /mnt/storage** (Recommended for important data)

```bash
# Create backup in /mnt/storage (will be picked up by restic)
ssh root@192.168.1.186 "tar czf /mnt/storage/backups/wishlist/wishlist-backup-$(date +%Y%m%d).tar.gz /opt/wishlist/data /opt/wishlist/uploads"

# Cleanup old backups (keep last 30 days)
ssh root@192.168.1.186 "find /mnt/storage/backups/wishlist -name 'wishlist-backup-*.tar.gz' -mtime +30 -delete"
```

This approach:
- Stores backups on MergerFS pool at `/mnt/storage/backups/wishlist/`
- Automatically included in daily restic backup to Backblaze B2
- Subject to existing retention policy (7 daily, 4 weekly, 6 monthly, 2 yearly)
- Transparent and leverages existing backup infrastructure

**Option B: Add restic backup policy for container data**

Would require creating a new restic backup policy that:
- Runs on the wishlist container (not Proxmox host)
- Backs up `/opt/wishlist/data` and `/opt/wishlist/uploads`
- Uses separate B2 bucket or adds to existing bucket with different tags

**Trade-offs:**
- More complex configuration
- Requires restic installation on wishlist container
- Adds backup overhead to a lightweight container
- Not recommended for low-volume personal applications

---

## Automated Backup Script (Optional Enhancement)

If regular automated backups are desired, create a simple cron job or systemd timer on the wishlist container:

```bash
# /usr/local/bin/backup-wishlist.sh
#!/bin/bash
set -euo pipefail

BACKUP_DIR="/mnt/storage/backups/wishlist"
DATE=$(date +%Y%m%d)
BACKUP_FILE="$BACKUP_DIR/wishlist-backup-$DATE.tar.gz"

# Create backup
tar czf "$BACKUP_FILE" /opt/wishlist/data /opt/wishlist/uploads

# Cleanup old backups (keep 30 days)
find "$BACKUP_DIR" -name 'wishlist-backup-*.tar.gz' -mtime +30 -delete

echo "Backup completed: $BACKUP_FILE"
```

**Systemd timer configuration:**

```ini
# /etc/systemd/system/wishlist-backup.timer
[Unit]
Description=Daily wishlist data backup

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
```

---

## Database Migration Safety

Before running Prisma migrations (especially during application updates):

1. **Stop the service**: `systemctl stop wishlist`
2. **Backup database**: `cp /opt/wishlist/data/prod.db /opt/wishlist/data/prod.db.pre-migration`
3. **Run migration**: `pnpm prisma migrate deploy`
4. **Verify**: Check application logs for errors
5. **Start service**: `systemctl start wishlist`

If migration fails, restore from pre-migration backup.

---

## Disaster Recovery Scenarios

### Scenario 1: Database Corruption

**Symptoms**: Service fails to start, SQLite errors in logs

**Recovery:**
1. Stop service: `systemctl stop wishlist`
2. Move corrupted DB: `mv /opt/wishlist/data/prod.db /opt/wishlist/data/prod.db.corrupted`
3. Restore from backup: `tar xzf ~/backups/wishlist-backup-YYYYMMDD.tar.gz -C /`
4. Fix permissions: `chown -R wishlist:wishlist /opt/wishlist/data`
5. Start service: `systemctl start wishlist`

### Scenario 2: Accidental Data Deletion

**Symptoms**: User accidentally deleted wishlists or items

**Recovery:**
- Restore database from most recent backup (see "Restore from Backup" above)
- Data loss limited to changes since last backup

### Scenario 3: Failed Application Update

**Symptoms**: Service won't start after git pull + rebuild

**Recovery:**
1. Stop service
2. Restore database from pre-update backup
3. Revert code: `cd /opt/wishlist/repo && git reset --hard HEAD^`
4. Rebuild: `pnpm install && pnpm build`
5. Start service

### Scenario 4: Complete Container Failure

**Symptoms**: Container won't boot, filesystem corruption

**Recovery Options:**
1. **Data-only restore**: Create new CT307, redeploy via Ansible, restore data from tar backup
2. **Full container restore**: Use Proxmox vzdump backup to restore entire container
3. **Rebuild from scratch**: Terraform + Ansible + data restore

---

## Monitoring Backup Health

### Check Backup Exists

```bash
# Local backups
ls -lht ~/backups/wishlist-backup-*.tar.gz | head -5

# On-container backups
ssh root@192.168.1.186 "ls -lht /opt/wishlist/data/*.backup* | head -5"

# MergerFS backups (if using Option A)
ssh cuiv@homelab "ls -lht /mnt/storage/backups/wishlist/ | head -5"
```

### Check Database Size Trends

```bash
# Monitor database growth
ssh root@192.168.1.186 "du -sh /opt/wishlist/data /opt/wishlist/uploads"

# Check SQLite database info
ssh root@192.168.1.186 "sqlite3 /opt/wishlist/data/prod.db 'SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size();'" | numfmt --to=iec-i
```

---

## Recommendation Summary

**For wishlist deployment:**

1. **Document manual backup procedures** (this document) ✅
2. **Include backup reminder in quick reference guide** ✅
3. **Store backups in `/mnt/storage/backups/wishlist/`** (covered by existing restic)
4. **Always backup before updates** (documented in update procedures)
5. **Rely on Proxmox vzdump as disaster recovery safety net**

**Automated daily backup to /mnt/storage is recommended if:**
- Wishlist becomes heavily used
- Multiple users are actively using the application
- Data becomes difficult to recreate manually

For initial deployment, manual backup procedures are sufficient given the low-risk, personal nature of the application.

---

**Maintenance:** Review this strategy after 3 months of usage and adjust if data volume or criticality increases.
