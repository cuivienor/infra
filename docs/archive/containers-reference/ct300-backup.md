# CT300: Backup Container

**Status**: ✅ Production  
**Purpose**: Automated backups of `/mnt/storage` to Backblaze B2  
**Created**: 2025-11-11  
**Last Updated**: 2025-11-11

---

## Overview

CT300 runs automated backups of important homelab data to Backblaze B2 using restic. It backs up photos, personal documents, and configuration backups while excluding large media files that can be re-ripped.

**What it backs up**: ~227GB
- Photos (`photos/`)
- Personal documents (`archives/personal-documents/`)
- Configuration backups (`archives/backups/`)
- Misc documents/downloads

**What it excludes**: ~3.6TB
- All media (movies, TV, audiobooks, ebooks, staging)
- Private content
- Google Takeout archive
- Old Photos directory (pending deletion)

---

## Quick Reference

| Property | Value |
|----------|-------|
| **CTID** | 300 |
| **Hostname** | backup |
| **IP Address** | 192.168.1.58 (DHCP) |
| **OS** | Debian 12 |
| **Resources** | 2 CPU cores, 2GB RAM, 20GB disk |
| **Managed By** | Terraform + Ansible |

---

## Access

### SSH Access
```bash
# Direct SSH
ssh root@192.168.1.58

# Via Proxmox
pct enter 300
```

### Key Files & Directories
- **Config**: `/etc/restic/`
- **Scripts**: `/etc/restic/scripts/`
- **Logs**: `/var/log/restic/`
- **Cache**: `/var/cache/restic/`
- **Storage Mount**: `/mnt/storage/` (read-only from host)

---

## Operations

### Check Backup Status

**Current backup running?**
```bash
ssh root@192.168.1.58 "systemctl status restic-backup-data.service"
```

**View live backup progress:**
```bash
ssh root@192.168.1.58 "journalctl -u restic-backup-data.service -f"
```

**Check last backup log:**
```bash
ssh root@192.168.1.58 "ls -lt /var/log/restic/backup-data-*.log | head -1 | awk '{print \$NF}' | xargs tail -50"
```

### View Snapshots

**List all snapshots:**
```bash
ssh root@192.168.1.58 "/etc/restic/scripts/maintenance.sh snapshots data"
```

**Show repository stats:**
```bash
ssh root@192.168.1.58 "source /etc/restic/data.env && restic stats"
```

**View specific snapshot contents:**
```bash
ssh root@192.168.1.58 "source /etc/restic/data.env && restic ls <snapshot-id>"
```

### Manual Backup Operations

**Start backup immediately:**
```bash
ssh root@192.168.1.58 "systemctl start restic-backup-data.service"
```

**Stop running backup:**
```bash
ssh root@192.168.1.58 "systemctl stop restic-backup-data.service"
```

**Check backup timer (scheduled backups):**
```bash
ssh root@192.168.1.58 "systemctl list-timers restic-*"
```

### Restore Operations

**Restore specific file/directory:**
```bash
ssh root@192.168.1.58 "/etc/restic/scripts/restore.sh data latest /restore /mnt/storage/photos/vacation"
```

**Restore entire snapshot to directory:**
```bash
ssh root@192.168.1.58 "source /etc/restic/data.env && restic restore latest --target /restore"
```

**Mount snapshot as filesystem (read-only):**
```bash
ssh root@192.168.1.58 "source /etc/restic/data.env && mkdir -p /mnt/restic && restic mount /mnt/restic"
# Browse in another terminal, then unmount with Ctrl+C
```

### Maintenance

**Check repository integrity:**
```bash
ssh root@192.168.1.58 "source /etc/restic/data.env && restic check"
```

**Remove orphaned data (prune):**
```bash
# From your local machine:
cd ~/dev/homelab-notes
./scripts/utils/cleanup-backup-orphans.sh

# Or manually:
ssh root@192.168.1.58 "source /etc/restic/data.env && restic prune --verbose"
```

**Apply retention policy manually:**
```bash
ssh root@192.168.1.58 "source /etc/restic/data.env && restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --keep-yearly 2 --prune"
```

**Unlock repository (if stuck):**
```bash
ssh root@192.168.1.58 "source /etc/restic/data.env && restic unlock"
```

---

## Troubleshooting

### Backup Failed

**Check service status:**
```bash
ssh root@192.168.1.58 "systemctl status restic-backup-data.service"
ssh root@192.168.1.58 "journalctl -u restic-backup-data.service -n 50 --no-pager"
```

**Common issues:**
- **Repository locked**: Previous backup crashed, run `restic unlock`
- **Network error**: Check B2 connectivity, verify credentials
- **Out of space**: Check container disk usage: `df -h`
- **Permission denied**: Verify `/mnt/storage` is mounted

### Backup Running Forever

**Check actual restic process:**
```bash
ssh root@192.168.1.58 "ps aux | grep restic"
```

**Kill stuck backup:**
```bash
ssh root@192.168.1.58 "systemctl stop restic-backup-data.service"
ssh root@192.168.1.58 "source /etc/restic/data.env && restic unlock"
```

### Storage Not Mounted

**Verify mount on host:**
```bash
ssh root@192.168.1.56 "pct mount 300"
```

**Check inside container:**
```bash
ssh root@192.168.1.58 "ls -la /mnt/storage/ && df -h /mnt/storage"
```

### B2 Credentials Not Working

**Test B2 connection:**
```bash
ssh root@192.168.1.58 "source /etc/restic/data.env && restic snapshots"
```

**Update credentials** (requires Ansible vault password):
```bash
cd ~/dev/homelab-notes
ansible-vault edit ansible/vars/backup_secrets.yml
# Update vault_b2_account_id, vault_b2_account_key, or vault_restic_password_data
ansible-playbook ansible/playbooks/ct300-backup.yml --vault-password-file .vault_pass
```

---

## Scheduled Tasks

### Backup Schedule

**Daily backup:**
- **Time**: 2:00 AM daily
- **Timer**: `restic-backup-data.timer`
- **Service**: `restic-backup-data.service`

**Check next run:**
```bash
ssh root@192.168.1.58 "systemctl list-timers restic-backup-data.timer"
```

### Integrity Check Schedule

**Weekly check:**
- **Time**: Sunday 3:00 AM
- **Timer**: `restic-check-data.timer`
- **Service**: `restic-check-data.service`

**Manual check:**
```bash
ssh root@192.168.1.58 "systemctl start restic-check-data.service"
```

---

## Configuration

### Backup Policy

**What's backed up:**
```yaml
paths:
  - /mnt/storage

excludes:
  - /mnt/storage/media/**              # 2.5TB - movies, TV, audiobooks, etc.
  - /mnt/storage/private/**            # 759GB - adult content
  - /mnt/storage/google-takeout/**     # 598GB - Google Photos archive
  - /mnt/storage/Photos-OLD-*/**       # 204GB - pending deletion
```

**Retention policy:**
- Keep last 7 daily snapshots
- Keep last 4 weekly snapshots
- Keep last 6 monthly snapshots
- Keep last 2 yearly snapshots

**Edit exclusions:**
```bash
cd ~/dev/homelab-notes
vim ansible/roles/restic_backup/defaults/main.yml
ansible-playbook ansible/playbooks/ct300-backup.yml --vault-password-file .vault_pass
```

### B2 Bucket

**Bucket**: `homelab-data-peter`  
**Region**: us-east-005  
**Type**: Private  
**Lifecycle**: Keep all versions (restic manages retention)  
**Encryption**: Disabled (restic encrypts)  

**View in B2**: https://secure.backblaze.com/b2_buckets.htm

### Resource Limits

**CPU**: 2 cores, Nice level 19 (low priority)  
**I/O**: Idle scheduling class  
**Memory**: 2GB dedicated  
**Disk**: 20GB (for cache and logs)  

**Adjust resources in Terraform:**
```bash
cd ~/dev/homelab-notes/terraform
vim ct300-backup.tf  # Edit cpu/memory/disk
terraform apply
```

---

## Costs

### Current Costs (as of 2025-11-11)

**Backblaze B2:**
- **Storage**: 227GB × $0.005/GB = **$1.14/month**
- **API calls**: Minimal (< $0.10/month)
- **Downloads**: First 1GB/day free
- **Total**: **~$1.20/month** (~$14/year)

**Proxmox:**
- Storage: 20GB LVM (negligible)
- CPU/RAM: Minimal usage (idle most of the time)

### Cost Optimizations Done
- Excluded media (saved $12.50/month)
- Excluded private content (saved $3.80/month)
- Excluded Google Takeout (saved $3.00/month)
- **Total savings**: ~$19/month vs backing up everything

---

## Updates & Maintenance

### Update Restic Version

**Check current version:**
```bash
ssh root@192.168.1.58 "restic version"
```

**Update via Ansible:**
```bash
cd ~/dev/homelab-notes
vim ansible/roles/restic_backup/defaults/main.yml  # Update restic_version
ansible-playbook ansible/playbooks/ct300-backup.yml --vault-password-file .vault_pass
```

### Reconfigure Container

**Full reconfiguration:**
```bash
cd ~/dev/homelab-notes/ansible
ansible-playbook playbooks/ct300-backup.yml --vault-password-file ../.vault_pass
```

**Update specific parts:**
```bash
# Update backup scripts only
ansible-playbook playbooks/ct300-backup.yml --vault-password-file ../.vault_pass --tags restic_backup

# Update SSH keys only
ansible-playbook playbooks/ct300-backup.yml --vault-password-file ../.vault_pass --tags ssh-keys
```

### Rebuild Container

**Destroy and recreate:**
```bash
cd ~/dev/homelab-notes/terraform

# Destroy (WARNING: Does not affect B2 data)
terraform destroy -target proxmox_virtual_environment_container.backup

# Recreate
terraform apply

# Reconfigure
cd ../ansible
ansible-playbook playbooks/ct300-backup.yml --vault-password-file ../.vault_pass
```

**Note**: Destroying the container does NOT delete B2 data. Your backups are safe.

---

## Monitoring

### Health Checks

**Quick health check:**
```bash
ssh root@192.168.1.58 "
  echo '=== Service Status ==='
  systemctl is-active restic-backup-data.timer
  echo '=== Last Backup ==='
  ls -lt /var/log/restic/backup-data-*.log | head -1
  echo '=== Snapshots ==='
  source /etc/restic/data.env && restic snapshots | tail -5
  echo '=== Disk Space ==='
  df -h / /var/cache/restic /var/log/restic
"
```

### Alerts to Watch For

**Signs of problems:**
- ⚠️ Backup timer not enabled
- ⚠️ No recent backup logs (> 24 hours)
- ⚠️ No snapshots exist
- ⚠️ Repository locked for extended period
- ⚠️ Disk usage > 80%
- ⚠️ B2 storage significantly different from expected

### Log Files

**Backup logs:**
```bash
/var/log/restic/backup-data-YYYYMMDD-HHMMSS.log
```

**Check logs:**
```bash
# Find failed backups
ssh root@192.168.1.58 "grep -l 'error\|failed' /var/log/restic/backup-data-*.log"

# View systemd logs
ssh root@192.168.1.58 "journalctl -u restic-backup-data.service --since today"
```

---

## Future Plans & Ideas

### Short Term
- [ ] Set up Backrest web UI (http://192.168.1.58:9898)
  - Provides visual interface for browsing/restoring backups
  - Installation: https://github.com/garethgeorge/backrest
  
- [ ] Test automated restore from snapshot
  - Verify full restore process works
  - Document recovery time objectives (RTO)
  
- [ ] Set up backup completion notifications
  - Email/webhook on backup success/failure
  - Consider using healthchecks.io or similar

- [ ] Test disaster recovery scenario
  - Simulate complete data loss
  - Restore from B2 to new system
  - Document full recovery procedure

### Medium Term
- [ ] Add monitoring/alerting
  - Prometheus exporter for restic metrics?
  - Alert on backup failures
  - Track backup size trends
  
- [ ] Optimize backup schedule
  - Consider incremental-only during weekdays
  - Full backup + prune on weekends
  
- [ ] Add backup verification
  - Randomly restore and verify files
  - Automated integrity testing

### Long Term
- [ ] Multiple backup destinations
  - Add second B2 bucket in different region
  - Consider local backup to NAS
  
- [ ] Backup other containers' configs
  - Add other containers to backup scope
  - LXC container configs, Docker volumes, etc.
  
- [ ] Performance optimization
  - Experiment with compression levels
  - Tune upload parallelization
  - Consider B2 bandwidth caps
  - Optimize cache location (SSD vs HDD for /var/cache/restic)
  - Evaluate container disk placement (local-lvm vs SSD)

### Ideas to Explore
- Backup rotation strategy with multiple repos
- Cost comparison: B2 vs AWS S3 Glacier
- Encrypted local cache for faster restores
- Off-site backup to friend's homelab (reciprocal)
- Backup to USB drive for quick local restores

---

## Related Documentation

- **IaC Files**:
  - Terraform: `terraform/ct300-backup.tf`
  - Ansible Playbook: `ansible/playbooks/ct300-backup.yml`
  - Ansible Role: `ansible/roles/restic_backup/`
  
- **Guides**:
  - [Backup Setup Guide](../guides/backup-setup.md)
  - [CT300 Deployment Guide](../guides/ct300-backup-deployment.md)
  
- **Reference**:
  - [Backup Quick Reference](../reference/backup-quick-reference.md)
  - [Restic Documentation](https://restic.readthedocs.io/)
  - [Backblaze B2 Documentation](https://www.backblaze.com/b2/docs/)

---

## Notes

### Lessons Learned
- Systemd hardening (PrivateTmp, ProtectSystem) doesn't work in LXC - had to disable
- Interrupted backups leave orphaned data in B2 - need to prune after
- API tokens can't create bind mounts - needed to use password auth in Terraform
- MergerFS directories exist on multiple disks - must move from actual disk, not MergerFS view

### Security Considerations
- Container is privileged (needs host storage mount)
- B2 credentials stored in container at `/etc/restic/data.env`
- Repository password also in `/etc/restic/data.env`
- Both encrypted in Ansible vault in repository
- SSH access via centralized key management

### Performance Notes
- First backup: ~2-4 hours for 227GB
- Incremental backups: ~10-30 minutes depending on changes
- Prune operation: ~5-10 minutes
- Restore: Depends on network speed and data size

---

**Last reviewed**: 2025-11-11  
**Maintained by**: cuiv
