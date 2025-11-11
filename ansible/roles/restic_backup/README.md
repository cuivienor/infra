# Restic Backup Ansible Role

Automated, encrypted backups to Backblaze B2 using restic.

## Features

- 🔒 **Encrypted**: All data encrypted before upload
- 📦 **Deduplicated**: Saves storage space and costs
- ⏱️ **Automated**: Systemd timers handle scheduling
- 🎯 **Multi-policy**: Different schedules for different data types
- 🔧 **Easy restore**: Helper scripts for quick recovery
- 📊 **Monitoring**: Systemd integration for status tracking

## Requirements

- Debian/Ubuntu-based system
- Backblaze B2 account with buckets created
- Network connectivity to B2
- Root or sudo access

## Role Variables

See `defaults/main.yml` for all available variables. Key variables:

```yaml
# Restic version
restic_version: "0.16.4"

# Backup user
backup_user: "media"

# Backup policies
backup_policies:
  - name: "sensitive"
    enabled: true
    paths:
      - "/mnt/storage/documents"
    schedule: "daily"
    retention:
      keep_daily: 7
      keep_weekly: 4
      keep_monthly: 6
      keep_yearly: 2
    b2_bucket: "{{ b2_bucket_sensitive }}"

# B2 credentials (store in vault)
b2_account_id: "{{ vault_b2_account_id }}"
b2_account_key: "{{ vault_b2_account_key }}"
restic_password_sensitive: "{{ vault_restic_password_sensitive }}"
```

## Vault Variables

Required in `vars/backup_secrets.yml` (encrypted with ansible-vault):

```yaml
vault_b2_account_id: "your_b2_account_id"
vault_b2_account_key: "your_b2_app_key"
vault_b2_bucket_sensitive: "homelab-sensitive"
vault_b2_bucket_media: "homelab-media"
vault_restic_password_sensitive: "strong_password_1"
vault_restic_password_media: "strong_password_2"
```

## Usage

### Basic Playbook

```yaml
---
- name: Configure backups
  hosts: proxmox_host
  become: true
  
  vars_files:
    - ../vars/backup_secrets.yml
  
  roles:
    - restic_backup
```

### Run Playbook

```bash
ansible-playbook playbooks/backup.yml --vault-password-file ~/.vault_pass
```

## Generated Files

The role creates:

- `/etc/restic/` - Configuration directory
  - `<policy>.env` - Repository credentials
  - `<policy>-excludes.txt` - Exclude patterns
  - `scripts/backup-<policy>.sh` - Backup scripts
  - `scripts/maintenance.sh` - Maintenance operations
  - `scripts/restore.sh` - Restore helper
- `/var/cache/restic/` - Restic cache
- `/var/log/restic/` - Backup logs
- `/etc/systemd/system/restic-*.{service,timer}` - Systemd units

## Manual Operations

```bash
# Run backup now
sudo systemctl start restic-backup-sensitive.service

# Check status
sudo systemctl status restic-backup-sensitive.timer

# List snapshots
sudo /etc/restic/scripts/maintenance.sh snapshots sensitive

# Restore files
sudo /etc/restic/scripts/restore.sh -p sensitive -t /tmp/restore

# Check repository
sudo /etc/restic/scripts/maintenance.sh check sensitive
```

## Testing

Always test your backups:

```bash
# Run test backup
sudo systemctl start restic-backup-sensitive.service

# Verify snapshot created
sudo /etc/restic/scripts/maintenance.sh snapshots sensitive

# Test restore
sudo /etc/restic/scripts/restore.sh -p sensitive -t /tmp/test

# Verify files
diff -r /mnt/storage/documents /tmp/test/mnt/storage/documents

# Clean up
rm -rf /tmp/test
```

## Expanding the Configuration

### Add New Backup Policy

1. Edit `defaults/main.yml`:
   ```yaml
   backup_policies:
     - name: "newpolicy"
       enabled: true
       paths:
         - "/path/to/backup"
       schedule: "daily"
       retention:
         keep_daily: 7
         keep_weekly: 4
       b2_bucket: "{{ b2_bucket_media }}"
   ```

2. Re-run playbook:
   ```bash
   ansible-playbook playbooks/backup.yml --vault-password-file ~/.vault_pass
   ```

### Add New Repository

1. Create B2 bucket at [Backblaze](https://secure.backblaze.com/b2_buckets.htm)

2. Add to vault:
   ```bash
   ansible-vault edit vars/backup_secrets.yml
   # Add: vault_b2_bucket_newbucket: "bucket-name"
   # Add: vault_restic_password_newbucket: "password"
   ```

3. Add policy using new bucket in `defaults/main.yml`

4. Re-run playbook

## Security

- All credentials stored in ansible-vault encrypted files
- Repository credentials are root-only readable on target system
- Restic encrypts all data before upload
- Use strong, unique passwords for each repository
- Store restic passwords in a password manager

## Troubleshooting

### Backup Failed

```bash
# Check logs
sudo journalctl -u restic-backup-sensitive.service -n 100

# Test credentials
source /etc/restic/sensitive.env
sudo restic snapshots
```

### Repository Locked

```bash
# Remove stale locks
sudo /etc/restic/scripts/maintenance.sh unlock sensitive
```

### Slow Performance

- Restic runs with `nice` and `ionice` to avoid impacting system
- Adjust `restic_nice_level` and `restic_ionice_class` if needed
- First backup is always slow (uploads all data)
- Subsequent backups are fast (incremental)

## Cost Optimization

- Enable deduplication (default)
- Set appropriate retention policies
- Don't backup unnecessary files (use excludes)
- Consider backup frequency vs. storage costs
- Monitor B2 usage regularly

**Backblaze B2 Pricing**:
- Storage: $0.005/GB/month
- Download: $0.01/GB (first 3x storage free)

## Future Enhancements

Planned improvements:
- Email notifications on failure
- Healthchecks.io integration
- Prometheus metrics export
- Backup verification automation
- Multi-destination support (local + cloud)

## License

Part of homelab-notes infrastructure repository.

## Author

cuiv - Homelab Infrastructure
