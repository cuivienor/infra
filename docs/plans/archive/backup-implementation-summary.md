# Backup Implementation Summary

**Created**: 2025-11-11  
**Status**: Ready for deployment

---

## What Was Built

A complete **Infrastructure as Code** backup solution for `/mnt/storage` data:

### Components

1. **Terraform Configuration**
   - Creates CT300 (backup container) on Proxmox
   - 2 cores, 2GB RAM, 20GB disk
   - Auto-assigned DHCP IP
   - File: `terraform/containers/ct300-backup.tf`

2. **Ansible Role: `restic_backup`**
   - Installs restic binary
   - Configures automated backups to Backblaze B2
   - Sets up systemd timers (daily backups)
   - Includes restore scripts
   - Location: `ansible/roles/restic_backup/`

3. **Backup Policy: `data`**
   - Backs up ALL of `/mnt/storage` except large media
   - **Included**: photos, documents, backups, e-books, audiobooks
   - **Excluded**: Movies, TV, media pipeline, temp files
   - **Schedule**: Daily at 2 AM (via systemd timer)
   - **Retention**: 7 daily, 4 weekly, 6 monthly, 2 yearly

4. **Documentation**
   - Deployment guide: `docs/guides/ct300-backup-deployment.md`
   - Quick reference: `docs/reference/backup-quick-reference.md`
   - Setup guide: `docs/guides/backup-setup.md`
   - Terraform README: `terraform/README.md`

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  Proxmox Host (homelab)                     │
│                                             │
│  /mnt/storage (35TB MergerFS)               │
│  ├── photos/          ✅ Backed up          │
│  ├── documents/       ✅ Backed up          │
│  ├── backups/         ✅ Backed up          │
│  ├── e-books/         ✅ Backed up          │
│  ├── Movies/          ❌ Excluded           │
│  └── media/           ❌ Excluded           │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │ CT300: Backup Container               │  │
│  │ - Debian 12                           │  │
│  │ - Mounts: /mnt/storage (read-only)    │  │
│  │                                       │  │
│  │ Services:                             │  │
│  │ - restic (backup engine)              │  │
│  │ - systemd timer (daily 2am)           │  │
│  │ - (Future: Backrest UI on :9898)      │  │
│  └───────────────────────────────────────┘  │
│               │                             │
└───────────────┼─────────────────────────────┘
                │
                ▼
        ┌───────────────┐
        │  Backblaze B2 │
        │               │
        │  homelab-data │
        │  (encrypted)  │
        └───────────────┘
```

---

## How It Works

### Daily Backup Workflow

1. **Systemd timer triggers** at 2 AM daily
2. **Backup script runs**:
   - Sources `/etc/restic/data.env` (B2 credentials)
   - Runs `restic backup /mnt/storage --exclude-file=...`
   - Uploads only changed data (deduplication)
   - Runs `restic forget --prune` (cleanup old snapshots)
3. **Logs to** `/var/log/restic/backup-data-YYYYMMDD-HHMMSS.log`
4. **Data encrypted** with restic before upload to B2

### IaC Management

```bash
# 1. Deploy container
cd ~/dev/homelab-notes/terraform
terraform apply

# 2. Configure backups
export CT300_IP="192.168.1.XXX"
ansible-playbook ansible/playbooks/ct300-backup.yml --vault-password-file ~/.vault_pass

# 3. Monitor
ssh homelab "pct exec 300 -- systemctl status restic-backup-data.timer"
```

### Configuration Management

All configuration is version controlled:

```
homelab-notes/
├── terraform/
│   ├── containers/ct300-backup.tf    # Container definition
│   └── terraform.tfvars              # Proxmox credentials (git-ignored)
├── ansible/
│   ├── roles/restic_backup/          # Backup configuration
│   ├── playbooks/ct300-backup.yml    # Container playbook
│   └── vars/backup_secrets.yml       # B2/restic secrets (encrypted)
```

Changes to backup policy:
1. Edit `ansible/roles/restic_backup/defaults/main.yml`
2. Commit to git
3. Re-run Ansible playbook
4. Backups automatically use new configuration

---

## What You Get

### ✅ Automated Backups
- Daily encrypted backups to B2
- Incremental (only changed data)
- Automatic retention (7d/4w/6m/2y)

### ✅ Full IaC Control
- Container defined in Terraform
- Backup config in Ansible
- All in version control
- Reproducible from scratch

### ✅ Disaster Recovery
- Restore from B2 anytime
- Helper scripts for easy restore
- Works even if Proxmox is destroyed

### ✅ Cost Effective
- Only pay for data stored
- Deduplication reduces size
- Estimated: $0.50-$2.50/month for typical data

### ✅ Monitoring Ready
- Systemd integration (view with `systemctl status`)
- Logs in `/var/log/restic/`
- (Future: Backrest UI for browsing snapshots)

---

## Future Enhancements (Optional)

### Phase 2: Add Backrest UI
- Install Backrest in CT300
- Browse snapshots via web UI (port 9898)
- Restore files through GUI
- Monitor backup health

### Phase 3: Additional Backup Policies
- `config`: Proxmox configs, LXC configs
- `databases`: If you add databases later
- `containers`: LXC container filesystems

### Phase 4: Multi-Destination
- Add local backup target (USB drive)
- Add family member's NAS (complete 3-2-1 rule)

### Phase 5: Notifications
- Email on backup failure
- Slack/Discord notifications
- Healthchecks.io integration

---

## Cost Breakdown

### B2 Storage Costs

Assuming typical homelab data:

| Data Size | Monthly | Annual |
|-----------|---------|--------|
| 50 GB     | $0.25   | $3.00  |
| 100 GB    | $0.50   | $6.00  |
| 250 GB    | $1.25   | $15.00 |
| 500 GB    | $2.50   | $30.00 |
| 1 TB      | $5.00   | $60.00 |

**Pricing**: $0.005/GB/month  
**Download**: $0.01/GB (first 3x storage free)

**Deduplication** typically reduces actual storage by 20-50%.

### Example

If you have:
- 100 GB photos
- 50 GB documents
- 25 GB backups
- 75 GB e-books/audiobooks

**Total**: 250 GB  
**After dedup**: ~150 GB  
**Cost**: **$0.75/month** or **$9/year**

---

## Security

### What's Encrypted
- ✅ All data encrypted by restic before upload
- ✅ B2 credentials encrypted with Ansible Vault
- ✅ Restic passwords encrypted with Ansible Vault

### What's Protected
- ✅ Proxmox password in `terraform.tfvars` (git-ignored)
- ✅ B2 credentials in `/etc/restic/data.env` (600 permissions)
- ✅ Restic password never stored in plaintext

### Credential Locations
- **Terraform**: `terraform/terraform.tfvars` (git-ignored)
- **Ansible**: `ansible/vars/backup_secrets.yml` (vault-encrypted)
- **Container**: `/etc/restic/data.env` (root-only)

---

## Testing Checklist

Before relying on backups:

- [ ] Initial backup completes successfully
- [ ] Snapshot appears in B2 bucket
- [ ] Test restore of a file
- [ ] Verify restored file matches original
- [ ] Timer is active and scheduled
- [ ] View logs to confirm no errors

**Monthly testing**:
- [ ] Run test restore
- [ ] Verify backup size is reasonable
- [ ] Check B2 costs
- [ ] Review retention (old snapshots pruned)

---

## Key Files Reference

### Terraform
- `terraform/main.tf` - Provider config
- `terraform/variables.tf` - Variable definitions
- `terraform/containers/ct300-backup.tf` - Container definition
- `terraform/terraform.tfvars` - Your secrets (git-ignored)

### Ansible
- `ansible/roles/restic_backup/defaults/main.yml` - Backup policies
- `ansible/roles/restic_backup/tasks/` - Installation tasks
- `ansible/roles/restic_backup/templates/` - Config templates
- `ansible/playbooks/ct300-backup.yml` - Container playbook
- `ansible/vars/backup_secrets.yml` - B2/restic secrets (encrypted)

### Documentation
- `docs/guides/ct300-backup-deployment.md` - Deployment walkthrough
- `docs/guides/backup-setup.md` - Detailed backup guide
- `docs/reference/backup-quick-reference.md` - Command reference
- `terraform/README.md` - Terraform usage

### In Container (after deployment)
- `/etc/restic/data.env` - Repository credentials
- `/etc/restic/scripts/backup-data.sh` - Backup script
- `/etc/restic/scripts/restore.sh` - Restore helper
- `/etc/restic/scripts/maintenance.sh` - Maintenance commands
- `/var/log/restic/` - Backup logs
- `/var/cache/restic/` - Restic cache

---

## Quick Commands

```bash
# Deploy
cd ~/dev/homelab-notes/terraform
terraform apply
export CT300_IP="<ip>"
ansible-playbook ansible/playbooks/ct300-backup.yml --vault-password-file ~/.vault_pass

# Run backup
ssh homelab "pct exec 300 -- systemctl start restic-backup-data.service"

# View snapshots
ssh homelab "pct exec 300 -- /etc/restic/scripts/maintenance.sh snapshots data"

# Restore file
ssh homelab "pct exec 300 -- /etc/restic/scripts/restore.sh -p data -t /tmp/restore"

# Check status
ssh homelab "pct exec 300 -- systemctl status restic-backup-data.timer"
```

---

## Success Criteria

You'll know the backup system is working when:

1. ✅ Container created via Terraform
2. ✅ Ansible playbook completes without errors
3. ✅ First backup finishes successfully
4. ✅ Snapshot visible in B2 bucket
5. ✅ Test restore matches original file
6. ✅ Daily timer shows "next run" time
7. ✅ Logs show no errors

---

## Next Actions

1. **Get B2 credentials** from Backblaze
2. **Configure secrets** files
3. **Run Terraform** to create CT300
4. **Mount storage** on Proxmox host
5. **Run Ansible** to configure backups
6. **Test backup** and restore
7. **Monitor** first week of automated backups

---

**This is your first fully IaC-managed container!** 🎉

The workflow you establish here (Terraform → Ansible → Test) will be the template for all future containers.

---

**Last Updated**: 2025-11-11
