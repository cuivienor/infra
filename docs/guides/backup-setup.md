# Restic Backup Setup Guide

**Status**: Implementation Ready  
**Last Updated**: 2025-11-11  
**Target**: Proxmox host `homelab` (192.168.1.56)

---

## Overview

This guide walks through setting up encrypted, automated backups of `/mnt/storage` to Backblaze B2 using restic.

### Backup Strategy (3-2-1 Rule)

Following the [Perfect Media Server backup strategy](https://perfectmediaserver.com/04-day-two/backups/):

1. **Copy 1**: Live data on MergerFS pool (35TB) with SnapRAID parity
2. **Copy 2**: Encrypted restic backups to Backblaze B2 (cloud) ✨ **This guide**
3. **Copy 3**: Future local/family member backup (planned)

### Key Features

- ✅ **Encrypted**: All data encrypted with restic before upload
- ✅ **Deduplicated**: Only stores changed data, saves storage costs
- ✅ **Incremental**: Fast backups after initial upload
- ✅ **Automated**: Systemd timers handle scheduling
- ✅ **Multi-policy**: Different schedules for different data types
- ✅ **Modular**: Easy to expand to full system backups later

---

## Prerequisites

### 1. Backblaze B2 Account

1. Sign up at [backblaze.com](https://www.backblaze.com/b2/sign-up.html)
2. Go to **App Keys** → Create new application key
3. Save your **Account ID** and **Application Key** (shown only once!)

### 2. Create B2 Buckets

Create buckets at [B2 Buckets](https://secure.backblaze.com/b2_buckets.htm):

- `homelab-sensitive` - For documents, configs, personal data
- `homelab-media` - For media files (optional, large files)

**Recommended settings**:
- **Private** bucket (not public)
- **Lifecycle rules**: None (restic manages retention)
- **Object lock**: Disabled (restic needs to delete old snapshots)

### 3. Generate Restic Passwords

Generate strong passwords for your restic repositories:

```bash
# On your workstation or homelab
openssl rand -base64 32  # For sensitive repo
openssl rand -base64 32  # For media repo
```

**CRITICAL**: Store these passwords in a password manager! You cannot recover data without them.

---

## Installation

### Step 1: Configure Secrets

1. Copy the example secrets file:
   ```bash
   cd ~/dev/homelab-notes/ansible/vars
   cp backup_secrets.yml.example backup_secrets.yml
   ```

2. Edit the secrets file:
   ```bash
   nano backup_secrets.yml
   ```

3. Fill in your credentials:
   ```yaml
   vault_b2_account_id: "your_account_id"
   vault_b2_account_key: "your_app_key"
   vault_b2_bucket_sensitive: "homelab-sensitive"
   vault_b2_bucket_media: "homelab-media"
   vault_restic_password_sensitive: "your_strong_password_1"
   vault_restic_password_media: "your_strong_password_2"
   ```

4. Encrypt the file with ansible-vault:
   ```bash
   ansible-vault encrypt backup_secrets.yml
   # Enter a vault password (different from restic passwords!)
   ```

5. Save vault password for future use:
   ```bash
   echo "your_vault_password" > ~/.vault_pass
   chmod 600 ~/.vault_pass
   ```

### Step 2: Review Backup Policies

Edit `ansible/roles/restic_backup/defaults/main.yml` to customize:

```yaml
backup_policies:
  # Sensitive data - daily backups
  - name: "sensitive"
    enabled: true
    paths:
      - "/mnt/storage/documents"  # Adjust to your paths
      - "/mnt/storage/photos"
    schedule: "daily"
    retention:
      keep_daily: 7
      keep_weekly: 4
      keep_monthly: 6
      keep_yearly: 2

  # Media staging - weekly backups
  - name: "staging"
    enabled: true
    paths:
      - "/mnt/storage/media/staging"
    schedule: "weekly"
    retention:
      keep_daily: 3
      keep_weekly: 4
      keep_monthly: 3

  # Full media library - disabled by default (expensive!)
  - name: "library"
    enabled: false  # Enable when ready
    paths:
      - "/mnt/storage/media/movies"
      - "/mnt/storage/media/tv"
    schedule: "monthly"
```

### Step 3: Run Ansible Playbook

Deploy the backup configuration:

```bash
cd ~/dev/homelab-notes
ansible-playbook ansible/playbooks/backup.yml --ask-vault-pass
# Or if using vault password file:
ansible-playbook ansible/playbooks/backup.yml --vault-password-file ~/.vault_pass
```

This will:
1. Install restic binary
2. Create configuration files
3. Initialize B2 repositories
4. Set up systemd timers
5. Start automated backups

---

## Usage

### Manual Backup Commands

```bash
# Run a backup immediately
sudo systemctl start restic-backup-sensitive.service

# Check backup status
sudo systemctl status restic-backup-sensitive.timer
sudo systemctl status restic-backup-sensitive.service

# View backup logs
sudo journalctl -u restic-backup-sensitive.service -f

# List all timers
sudo systemctl list-timers restic-*
```

### Viewing Snapshots

```bash
# List all snapshots for a policy
sudo /etc/restic/scripts/maintenance.sh snapshots sensitive

# View repository stats
sudo /etc/restic/scripts/maintenance.sh stats sensitive

# Check repository integrity
sudo /etc/restic/scripts/maintenance.sh check sensitive
```

### Restoring Files

The restore script provides an interactive interface:

```bash
# Show help
sudo /etc/restic/scripts/restore.sh -h

# Restore latest backup to /tmp/restore
sudo /etc/restic/scripts/restore.sh -p sensitive -t /tmp/restore

# Restore specific directory
sudo /etc/restic/scripts/restore.sh \
  -p sensitive \
  -t /tmp/restore \
  -r /mnt/storage/documents/important

# Restore specific snapshot (get ID from snapshots list)
sudo /etc/restic/scripts/restore.sh \
  -p sensitive \
  -s abc123def \
  -t /tmp/restore
```

### Maintenance Commands

```bash
# Check repository integrity (weekly automated, or manual)
sudo /etc/restic/scripts/maintenance.sh check all

# View statistics for all repos
sudo /etc/restic/scripts/maintenance.sh stats all

# Remove stale locks (if backup was interrupted)
sudo /etc/restic/scripts/maintenance.sh unlock sensitive

# Manual prune (usually automatic after backups)
sudo /etc/restic/scripts/maintenance.sh prune sensitive
```

---

## Testing Your Backups

**CRITICAL**: Regularly test that you can restore from backups!

### Initial Test (Do This First!)

1. Run a test backup:
   ```bash
   sudo systemctl start restic-backup-sensitive.service
   sudo journalctl -u restic-backup-sensitive.service -n 50
   ```

2. Verify backup succeeded:
   ```bash
   sudo /etc/restic/scripts/maintenance.sh snapshots sensitive
   ```

3. Test restore:
   ```bash
   # Pick a small file you can verify
   sudo /etc/restic/scripts/restore.sh -p sensitive -t /tmp/restore-test

   # Check the restored files
   ls -lah /tmp/restore-test
   diff -r /mnt/storage/documents /tmp/restore-test/mnt/storage/documents
   ```

4. Clean up:
   ```bash
   rm -rf /tmp/restore-test
   ```

### Regular Testing (Monthly)

Add a calendar reminder to test restore monthly:

```bash
# Test restore of a random file
sudo /etc/restic/scripts/restore.sh -p sensitive -t /tmp/test-$(date +%Y%m%d)
# Verify it matches the original
# Clean up
```

---

## Cost Estimates

Backblaze B2 pricing (as of 2025):
- **Storage**: $0.005/GB/month ($5 per TB/month)
- **Download**: $0.01/GB (first 3x storage free per month)
- **API calls**: Minimal cost (Class B: $0.004 per 10,000)

### Example Costs

| Data Size | Monthly Cost | Annual Cost |
|-----------|--------------|-------------|
| 100 GB    | $0.50        | $6.00       |
| 500 GB    | $2.50        | $30.00      |
| 1 TB      | $5.00        | $60.00      |
| 5 TB      | $25.00       | $300.00     |

**Note**: Restic deduplication significantly reduces actual storage used.

---

## Troubleshooting

### Backup Failed

```bash
# Check logs
sudo journalctl -u restic-backup-sensitive.service -n 100

# Common issues:
# 1. Network connectivity
ping -c 3 backblaze.com

# 2. B2 credentials
source /etc/restic/sensitive.env
restic snapshots  # Should list snapshots or show auth error

# 3. Lock conflict (backup already running)
sudo /etc/restic/scripts/maintenance.sh unlock sensitive
```

### Repository Corrupted

```bash
# Run integrity check
sudo /etc/restic/scripts/maintenance.sh check sensitive

# Rebuild index (if needed)
source /etc/restic/sensitive.env
restic rebuild-index
```

### Out of Space on B2

```bash
# Check repository size
sudo /etc/restic/scripts/maintenance.sh stats sensitive

# Manual prune to reclaim space
sudo /etc/restic/scripts/maintenance.sh prune sensitive
```

---

## Monitoring

### Check Backup Health

```bash
# View timer status
sudo systemctl list-timers restic-*

# Check last backup time
sudo systemctl status restic-backup-sensitive.timer

# View recent logs
sudo tail -f /var/log/restic/backup-sensitive-*.log | tail -1
```

### Set Up Alerts (Future Enhancement)

Consider adding:
- Email notifications on failure
- Healthchecks.io integration
- Prometheus metrics export

---

## Expansion Path

This setup is designed to grow with your needs:

### Phase 1 (Current): File Backups
- ✅ Sensitive data (documents, photos)
- ✅ Media staging area
- ⏳ Full media library (when budget allows)

### Phase 2: System Configuration
- Proxmox configuration (`/etc/pve/`)
- LXC container configs
- Ansible playbooks (already in git!)
- Scripts and automation

### Phase 3: Full System Backup
- Container filesystems
- Database dumps
- Application data

### Phase 4: Multi-System
- Backup other machines
- Family member systems
- Remote locations (3-2-1 rule completion)

To add new backup policies, edit `ansible/roles/restic_backup/defaults/main.yml` and re-run the playbook.

---

## Security Notes

### What's Encrypted

- ✅ **All data in B2**: Restic encrypts before upload
- ✅ **Credentials on disk**: Ansible vault encrypted
- ✅ **Repository passwords**: Never stored unencrypted

### Security Best Practices

1. **Use strong, unique passwords** for each repository
2. **Store passwords in password manager** (1Password, Bitwarden, etc.)
3. **Keep vault password secure** (consider using TPM or hardware key)
4. **Regularly rotate B2 application keys** (Backblaze supports multiple keys)
5. **Enable 2FA on Backblaze account**
6. **Monitor B2 access logs** for suspicious activity

### Credential Locations

- B2 credentials: `/etc/restic/*.env` (root-only readable)
- Restic passwords: `/etc/restic/*.env` (root-only readable)
- Ansible vault: `~/dev/homelab-notes/ansible/vars/backup_secrets.yml` (encrypted)

---

## Quick Reference

### File Locations

| Path | Description |
|------|-------------|
| `/etc/restic/` | Configuration root |
| `/etc/restic/scripts/` | Backup, restore, and maintenance scripts |
| `/etc/restic/*.env` | Repository credentials (encrypted on disk) |
| `/var/cache/restic/` | Restic cache (speeds up operations) |
| `/var/log/restic/` | Backup logs (kept for 30 days) |

### Important Commands

```bash
# Run backup now
sudo systemctl start restic-backup-<policy>.service

# List snapshots
sudo /etc/restic/scripts/maintenance.sh snapshots <policy>

# Restore files
sudo /etc/restic/scripts/restore.sh -p <policy> -t /tmp/restore

# Check repository
sudo /etc/restic/scripts/maintenance.sh check <policy>

# View logs
sudo journalctl -u restic-backup-<policy>.service
```

---

## Next Steps

1. ✅ Set up credentials and run initial backup
2. ✅ Test restore immediately
3. 📅 Set calendar reminder for monthly restore tests
4. 📊 Monitor first week of backups
5. 💰 Review B2 costs after first month
6. 🔄 Add more backup policies as needed
7. 📝 Document any customizations

---

**Remember**: The best backup is the one you test regularly. Set up that monthly restore test now!
