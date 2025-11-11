# Backup Quick Reference

**Quick commands for daily backup operations**

---

## Common Tasks

### Run Backup Now

```bash
# Sensitive data
sudo systemctl start restic-backup-sensitive.service

# Media staging
sudo systemctl start restic-backup-staging.service

# All policies
for policy in sensitive staging; do
    sudo systemctl start restic-backup-${policy}.service
done
```

### Check Status

```bash
# View all backup timers
sudo systemctl list-timers restic-*

# Check specific backup status
sudo systemctl status restic-backup-sensitive.timer
sudo systemctl status restic-backup-sensitive.service

# View recent logs
sudo journalctl -u restic-backup-sensitive.service -n 50 --no-pager
```

### List Snapshots

```bash
# List snapshots for a policy
sudo /etc/restic/scripts/maintenance.sh snapshots sensitive

# View repository statistics
sudo /etc/restic/scripts/maintenance.sh stats sensitive

# All policies
sudo /etc/restic/scripts/maintenance.sh snapshots all
```

### Restore Files

```bash
# Restore latest backup
sudo /etc/restic/scripts/restore.sh -p sensitive -t /tmp/restore

# Restore specific directory
sudo /etc/restic/scripts/restore.sh \
  -p sensitive \
  -t /tmp/restore \
  -r /mnt/storage/documents/important

# Restore specific snapshot (get ID from snapshots list)
sudo /etc/restic/scripts/restore.sh -p sensitive -s abc123 -t /tmp/restore
```

---

## Maintenance

### Check Repository Health

```bash
# Quick check (5% data verification)
sudo /etc/restic/scripts/maintenance.sh check sensitive

# Full check (all data)
source /etc/restic/sensitive.env
sudo restic check --read-data
```

### Fix Issues

```bash
# Remove stale locks (if backup interrupted)
sudo /etc/restic/scripts/maintenance.sh unlock sensitive

# Rebuild index (if corrupted)
source /etc/restic/sensitive.env
sudo restic rebuild-index

# Prune old data (reclaim space)
sudo /etc/restic/scripts/maintenance.sh prune sensitive
```

---

## Monitoring

### View Logs

```bash
# Live backup log
sudo journalctl -u restic-backup-sensitive.service -f

# Last backup log file
sudo ls -lt /var/log/restic/backup-sensitive-*.log | head -1 | awk '{print $NF}'
sudo tail -50 $(ls -t /var/log/restic/backup-sensitive-*.log | head -1)

# All logs
sudo ls -lh /var/log/restic/
```

### Check Last Backup Time

```bash
# Via systemd
sudo systemctl status restic-backup-sensitive.timer | grep Trigger

# Via restic
source /etc/restic/sensitive.env
sudo restic snapshots --last
```

---

## Manual Operations

### Direct Restic Commands

```bash
# Load environment
source /etc/restic/sensitive.env

# List snapshots
sudo restic snapshots

# Show snapshot contents
sudo restic ls latest

# Find files
sudo restic find document.pdf

# Compare snapshots
sudo restic diff snapshot1 snapshot2

# Repository statistics
sudo restic stats

# Verify data integrity
sudo restic check
```

---

## Emergency Recovery

### Full System Down - Restore from B2

```bash
# Install restic on new system
wget https://github.com/restic/restic/releases/download/v0.16.4/restic_0.16.4_linux_amd64.bz2
bunzip2 restic_0.16.4_linux_amd64.bz2
chmod +x restic_0.16.4_linux_amd64
sudo mv restic_0.16.4_linux_amd64 /usr/local/bin/restic

# Set environment (you saved these passwords in password manager, right?)
export B2_ACCOUNT_ID="your_account_id"
export B2_ACCOUNT_KEY="your_app_key"
export RESTIC_REPOSITORY="b2:homelab-sensitive:/sensitive"
export RESTIC_PASSWORD="your_restic_password"

# List available snapshots
restic snapshots

# Restore latest
restic restore latest --target /mnt/restore

# Restore specific paths
restic restore latest --target /mnt/restore --include /mnt/storage/documents
```

---

## Configuration

### File Locations

| Path | Description |
|------|-------------|
| `/etc/restic/` | Main config directory |
| `/etc/restic/scripts/` | Backup/restore scripts |
| `/etc/restic/*.env` | Repository credentials |
| `/etc/restic/*-excludes.txt` | Exclude patterns |
| `/var/cache/restic/` | Local cache |
| `/var/log/restic/` | Backup logs |
| `/etc/systemd/system/restic-*` | Systemd units |

### Edit Configuration

```bash
# Edit backup policies
cd ~/dev/homelab-notes
nano ansible/roles/restic_backup/defaults/main.yml

# Edit secrets (encrypted)
ansible-vault edit ansible/vars/backup_secrets.yml

# Re-deploy after changes
ansible-playbook ansible/playbooks/backup.yml --vault-password-file ~/.vault_pass
```

---

## Backup Policies

### Current Policies

| Policy | Schedule | Retention | Paths |
|--------|----------|-----------|-------|
| `sensitive` | Daily | 7d/4w/6m/2y | Documents, photos, personal |
| `staging` | Weekly | 3d/4w/3m | Media staging area |
| `library` | Monthly (disabled) | 1d/1w/6m/2y | Movies, TV shows |

### Enable/Disable Policies

```bash
# Edit defaults
nano ~/dev/homelab-notes/ansible/roles/restic_backup/defaults/main.yml

# Find the policy and change:
enabled: true   # or false

# Re-deploy
cd ~/dev/homelab-notes
ansible-playbook ansible/playbooks/backup.yml --vault-password-file ~/.vault_pass
```

---

## Cost Tracking

### Check B2 Usage

```bash
# Repository size
sudo /etc/restic/scripts/maintenance.sh stats sensitive

# Login to B2 web interface
# https://secure.backblaze.com/b2_buckets.htm
```

### Estimate Costs

```bash
# Get size in GB
source /etc/restic/sensitive.env
SIZE_BYTES=$(sudo restic stats --mode restore-size --json | jq .total_size)
SIZE_GB=$((SIZE_BYTES / 1024 / 1024 / 1024))
MONTHLY_COST=$(echo "scale=2; $SIZE_GB * 0.005" | bc)

echo "Repository size: ${SIZE_GB}GB"
echo "Estimated monthly cost: \$${MONTHLY_COST}"
```

---

## Troubleshooting

### Backup Failed

```bash
# View error
sudo journalctl -u restic-backup-sensitive.service -n 100

# Test connectivity
ping -c 3 backblaze.com

# Test credentials
source /etc/restic/sensitive.env
sudo restic snapshots

# Remove lock if stuck
sudo /etc/restic/scripts/maintenance.sh unlock sensitive
```

### Slow Backups

```bash
# Check I/O priority (should be "idle")
systemctl show restic-backup-sensitive.service | grep -i io

# Monitor during backup
sudo iotop -o
sudo htop
```

### Repository Issues

```bash
# Check repository
sudo /etc/restic/scripts/maintenance.sh check sensitive

# Rebuild index
source /etc/restic/sensitive.env
sudo restic rebuild-index

# Prune (if index is corrupted)
sudo restic prune --max-repack-size 2G
```

---

## Testing Checklist

### Monthly Test (Set Reminder!)

- [ ] Check timer status: `sudo systemctl list-timers restic-*`
- [ ] View recent logs: `sudo ls -lh /var/log/restic/`
- [ ] Test restore: `sudo /etc/restic/scripts/restore.sh -p sensitive -t /tmp/test-$(date +%Y%m%d)`
- [ ] Verify files: Check restored files match originals
- [ ] Check B2 costs: Review usage on Backblaze dashboard
- [ ] Clean up: `rm -rf /tmp/test-*`

---

## Support Resources

- **Restic Docs**: https://restic.readthedocs.io/
- **Backblaze B2 Docs**: https://www.backblaze.com/b2/docs/
- **Perfect Media Server**: https://perfectmediaserver.com/04-day-two/backups/
- **Local Docs**: `~/dev/homelab-notes/docs/guides/backup-setup.md`

---

**Pro Tip**: Save this page's path in your shell aliases:
```bash
echo "alias backup-help='cat ~/dev/homelab-notes/docs/reference/backup-quick-reference.md | less'" >> ~/.bashrc
```
