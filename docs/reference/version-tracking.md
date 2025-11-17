# Version Tracking and Update Management

**Last Updated**: 2025-11-16

This document tracks all software versions in the homelab infrastructure and their update mechanisms.

---

## Update Coverage Summary

| Category | Auto-Update | Manual Check Required |
|----------|-------------|----------------------|
| Proxmox Host OS | Yes (unattended-upgrades) | Kernel updates may need reboot |
| Raspberry Pi OS | Yes (unattended-upgrades) | Kernel updates may need reboot |
| LXC Container OS | Yes (weekly script) | Check logs |
| APT Repository Apps | Yes (with container updates) | N/A |
| Pinned Binary Downloads | **No** | Quarterly review |
| Terraform Providers | Semver ranges | When running terraform init |

---

## Automatically Updated Components

### Host Operating Systems

| Host | Method | Schedule | Logs |
|------|--------|----------|------|
| Proxmox (homelab) | unattended-upgrades | Daily | `/var/log/unattended-upgrades/` |
| Pi4 (192.168.1.102) | unattended-upgrades | Daily | `/var/log/unattended-upgrades/` |
| Pi3 (192.168.1.101) | unattended-upgrades | Daily | `/var/log/unattended-upgrades/` |

**Check status:**
```bash
# On Proxmox host
ssh cuiv@homelab "sudo systemctl status apt-daily-upgrade.timer"
ssh cuiv@homelab "sudo ls -la /var/log/unattended-upgrades/"

# On Raspberry Pi
ssh cuiv@pi4 "sudo systemctl status apt-daily-upgrade.timer"
```

### LXC Container Updates

| Containers | Method | Schedule | Logs |
|------------|--------|----------|------|
| All (300-311) | `proxmox_container_updates` role | Sun 3:00 AM | `/var/log/container-updates.log` |

**Check status:**
```bash
ssh cuiv@homelab "sudo journalctl -u container-update --since today"
ssh cuiv@homelab "sudo tail -100 /var/log/container-updates.log"
```

### Application Updates via APT Repositories

| Application | Repository | Updated With |
|-------------|-----------|--------------|
| Jellyfin | repo.jellyfin.org | Container updates |
| Tailscale | pkgs.tailscale.com | Container updates |
| Caddy | dl.cloudsmith.io | Container updates |
| Intel GPU drivers | Debian repos | Container updates |
| Samba | Debian repos | Container updates |

### Self-Updating Applications

| Application | Mechanism | Check Location |
|-------------|-----------|----------------|
| AdGuard Home | Built-in auto-updater | AdGuard Home UI |

---

## Manually Tracked Versions (Requires Quarterly Review)

### Pinned Binary Downloads

| Component | Current Version | Config Location | Check URL | Last Checked |
|-----------|----------------|-----------------|-----------|--------------|
| MakeMKV | 1.18.2 | `ansible/roles/makemkv/defaults/main.yml:7` | https://www.makemkv.com/download/ | 2025-11-16 |
| Restic | 0.16.4 | `ansible/roles/restic_backup/defaults/main.yml:4` | https://github.com/restic/restic/releases | 2025-11-16 |
| FileBot | 5.1.3 | `ansible/roles/media_analyzer/defaults/main.yml:8` | https://www.filebot.net/download/ | 2025-11-16 |
| MergerFS | 2.40.2 | `ansible/roles/proxmox_storage/defaults/main.yml:30` | https://github.com/trapexit/mergerfs/releases | 2025-11-16 |
| SnapRAID | 12.3 | `ansible/roles/proxmox_storage/defaults/main.yml:38` | https://github.com/amadvance/snapraid/releases | 2025-11-16 |

**Update Priority:**
- **HIGH**: Restic (backup integrity), MakeMKV (disc key updates)
- **MEDIUM**: FileBot (media database updates)
- **LOW**: MergerFS, SnapRAID (stable, infrequent updates)

### Terraform Providers

| Provider | Current Constraint | Config Location | Latest Check |
|----------|-------------------|-----------------|--------------|
| bpg/proxmox | ~> 0.50.0 | `terraform/main.tf:9` | Run `terraform init -upgrade` |
| tailscale/tailscale | ~> 0.16 | `terraform/main.tf:13` | Run `terraform init -upgrade` |

**Check for updates:**
```bash
cd terraform
terraform init -upgrade
terraform providers
```

---

## Quarterly Version Audit Checklist

Run this audit at the start of each quarter (Jan, Apr, Jul, Oct).

### Step 1: Check Pinned Versions

```bash
# Run the version check script
./scripts/check-updates.sh

# Or manually check:
# MakeMKV: https://www.makemkv.com/download/
# Restic: https://github.com/restic/restic/releases
# FileBot: https://www.filebot.net/download/
# MergerFS: https://github.com/trapexit/mergerfs/releases
# SnapRAID: https://github.com/amadvance/snapraid/releases
```

### Step 2: Check Terraform Providers

```bash
cd terraform
terraform init -upgrade
# Review any version changes
```

### Step 3: Review Update Logs

```bash
# Proxmox host updates
ssh cuiv@homelab "sudo cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -100"

# Container updates
ssh cuiv@homelab "sudo tail -200 /var/log/container-updates.log"

# Raspberry Pi updates
ssh cuiv@pi4 "sudo cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -50"
```

### Step 4: Check for Pending Reboots

```bash
# Proxmox host
ssh cuiv@homelab "sudo test -f /var/run/reboot-required && echo 'REBOOT REQUIRED' || echo 'No reboot needed'"

# Raspberry Pi
ssh cuiv@pi4 "sudo test -f /var/run/reboot-required && echo 'REBOOT REQUIRED' || echo 'No reboot needed'"
```

### Step 5: Update This Document

- Update "Last Checked" dates in the pinned versions table
- Note any version updates applied
- Record any issues encountered

---

## Update Procedures

### Updating Pinned Binary Versions

1. **Test in development/staging first** (if applicable)
2. Update version in Ansible defaults file
3. Run playbook with `--check` first
4. Apply changes during maintenance window
5. Verify service functionality
6. Update this document

Example for Restic:
```bash
# 1. Edit version
vim ansible/roles/restic_backup/defaults/main.yml

# 2. Check what would change
ansible-playbook ansible/playbooks/backup.yml --check --diff --vault-password-file .vault_pass

# 3. Apply
ansible-playbook ansible/playbooks/backup.yml --vault-password-file .vault_pass

# 4. Verify
ssh cuiv@homelab "sudo pct exec 300 -- restic version"
```

### Handling Kernel Updates (Requires Reboot)

Kernel updates are installed automatically but reboots are **disabled** to prevent unplanned outages.

**Planned Reboot Procedure:**
1. Check for pending reboot: `test -f /var/run/reboot-required`
2. Notify any users (if Jellyfin in use)
3. Stop critical services if needed
4. Reboot during maintenance window (e.g., early morning)
5. Verify all services come back up

```bash
# Check what needs rebooting
ssh cuiv@homelab "sudo cat /var/run/reboot-required.pkgs 2>/dev/null || echo 'No reboot needed'"

# Reboot Proxmox host (all containers will restart)
ssh cuiv@homelab "sudo reboot"

# Reboot Raspberry Pi (DNS may be briefly unavailable)
ssh cuiv@pi4 "sudo reboot"
```

---

## Security Considerations

### Critical Update Categories

1. **Kernel security patches** - Requires manual reboot planning
2. **OpenSSL updates** - May require service restarts
3. **SSH updates** - Critical for remote access security
4. **Proxmox VE updates** - Check Proxmox forums for known issues

### Monitoring for CVEs

Consider subscribing to:
- Proxmox Security Advisories: https://www.proxmox.com/en/news/security-advisories
- Debian Security Tracker: https://security-tracker.debian.org/
- Restic Security: GitHub watch on releases

---

## Troubleshooting

### Unattended-Upgrades Not Running

```bash
# Check timer status
systemctl status apt-daily-upgrade.timer

# Check logs
journalctl -u apt-daily-upgrade

# Manual test run
sudo unattended-upgrade --dry-run --debug
```

### Container Updates Failing

```bash
# Check update script logs
sudo tail -f /var/log/container-updates.log

# Check if container is marked as busy
sudo pct exec <CTID> -- pgrep -f "makemkv\|ffmpeg\|filebot"
```

### Disk Space Issues Preventing Updates

```bash
# Check disk space
df -h

# Clean old kernels (Proxmox)
sudo pve-kernel-cleaner

# Clean APT cache
sudo apt-get clean
```

---

## Future Improvements

- [ ] Set up Renovate bot for Terraform provider updates
- [ ] Implement GitHub release RSS monitoring for pinned versions
- [ ] Add email notifications for update failures
- [ ] Integrate with monitoring dashboard (Grafana)
- [ ] Consider security scanning (Trivy) for container images

---

**Maintenance**: Update this document whenever version changes are made or new components are added.
