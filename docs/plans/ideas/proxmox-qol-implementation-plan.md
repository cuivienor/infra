# Proxmox Quality of Life - Implementation Plan

This is a structured implementation plan for adding quality of life improvements to your Proxmox homelab. Each phase is self-contained and can be implemented independently.

---

## Phase 1: Post-Install Configuration & Cleanup

**Goal:** Fix repositories, remove subscription nag, clean up old kernels

**Prerequisites:**
- Root access to Proxmox host
- Backup of current system state

**Implementation Steps:**

### 1.1 Repository Configuration
```bash
# Create script: scripts/proxmox/fix-repositories.sh

# Tasks:
# - Check current PVE version (9.x expected)
# - Backup existing sources: /etc/apt/sources.list.d/
# - Disable pve-enterprise repository
# - Enable pve-no-subscription repository
# - Configure Debian Trixie repositories (deb822 format)
# - Run apt update to verify
```

**Manual verification:**
```bash
# After running, verify:
cat /etc/apt/sources.list.d/*.sources
apt update
```

**Testing:**
- Run on test VM first if available
- Verify apt update succeeds
- Verify web UI still accessible

**Rollback:**
- Restore backed up sources from backup directory

---

### 1.2 Remove Subscription Nag
```bash
# Create script: scripts/proxmox/remove-subscription-nag.sh

# Tasks:
# - Create /usr/local/bin/pve-remove-nag.sh
# - Patch /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
# - Patch /usr/share/pve-yew-mobile-gui/index.html.tpl (if exists)
# - Add APT post-invoke hook: /etc/apt/apt.conf.d/no-nag-script
# - Reinstall proxmox-widget-toolkit
```

**Testing:**
- Clear browser cache (Ctrl+Shift+R)
- Log out and log back in
- Verify no subscription popup appears

**Rollback:**
```bash
rm /usr/local/bin/pve-remove-nag.sh
rm /etc/apt/apt.conf.d/no-nag-script
apt reinstall proxmox-widget-toolkit
```

---

### 1.3 Kernel Cleanup
```bash
# Create script: scripts/proxmox/clean-old-kernels.sh

# Tasks:
# - Detect current running kernel: uname -r
# - List all installed kernels: dpkg --list | grep 'kernel-.*-pve'
# - Interactive selection (keep current + 1 previous)
# - Remove selected kernels: apt purge
# - Run update-grub
# - Show disk space freed
```

**Safety checks:**
- Never remove currently running kernel
- Keep at least 1 backup kernel
- Verify `/boot` has enough space before update-grub

**Testing:**
```bash
# Check boot partition space before/after
df -h /boot
```

**Rollback:**
- If boot issues: boot from older kernel in GRUB menu
- Reinstall kernel: apt install pve-kernel-<version>

---

## Phase 2: Automated Container Management

**Goal:** Automate container updates and cleanup

### 2.1 Container Update Script
```bash
# Create script: scripts/proxmox/update-containers.sh

# Features:
# - List all containers with status
# - Exclude containers by ID (interactive or config file)
# - Auto-start stopped containers, update, then stop
# - Support multi-distro:
#   - Debian/Ubuntu: apt update && apt dist-upgrade
#   - Alpine: apk upgrade
#   - Arch: pacman -Syu
#   - Fedora/Rocky: dnf update
# - Show disk usage before/after
# - Report containers needing reboot
# - Logging to /var/log/container-updates.log
```

**Configuration file:**
```yaml
# /etc/pve-scripts/container-update.conf
exclude_containers:
  - 100  # Test container
  - 999  # Template

auto_reboot: false
notify_on_completion: true
notification_url: "https://ntfy.sh/your-topic"
```

**Testing:**
- Run with --dry-run flag first
- Test on single non-critical container
- Verify updates applied correctly
- Check reboot detection works

**Rollback:**
- Container snapshots before updates
- Keep previous package versions available

---

### 2.2 Container Cleanup Script
```bash
# Create script: scripts/proxmox/cleanup-containers.sh

# Tasks per container:
# - Clear /var/cache/*
# - Clear /var/log/* (keep structure)
# - Clear /tmp/*
# - Run package manager cleanup:
#   - Debian/Ubuntu: apt autoremove, apt autoclean
#   - Alpine: apk cache clean
# - Report space freed per container
# - Total space freed across all containers
```

**Safety:**
- Never delete logs from containers tagged 'keep-logs'
- Exclude containers by ID
- Dry-run mode to preview

**Scheduling:**
```bash
# Create systemd timer: /etc/systemd/system/container-cleanup.timer
[Unit]
Description=Monthly container cleanup

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
```

---

### 2.3 Update Automation with Systemd Timer
```bash
# Create systemd service: /etc/systemd/system/container-update.service
# Create systemd timer: /etc/systemd/system/container-update.timer

# Timer config:
# - Weekly on Sunday at 3 AM
# - Persistent=true (run if missed)
# - Send notification on completion
```

**Integration with ntfy.sh:**
```bash
# In script:
function notify() {
    local message="$1"
    local priority="${2:-default}"
    curl -H "Priority: $priority" \
         -H "Title: Proxmox Container Updates" \
         -d "$message" \
         https://ntfy.sh/your-homelab-topic
}

# Usage:
notify "Container updates completed successfully" "low"
notify "Container update failed!" "high"
```

**Testing:**
```bash
# Test timer
systemctl start container-update.service
systemctl status container-update.service
journalctl -u container-update -f

# Test timer schedule
systemctl list-timers container-update
```

---

## Phase 3: Host Backup Automation

**Goal:** Automated, versioned backups of Proxmox host configuration

### 3.1 Host Backup Script
```bash
# Create script: scripts/proxmox/backup-host-config.sh

# What to backup:
BACKUP_PATHS=(
    "/etc/pve"                    # Proxmox config (VMs, containers, cluster)
    "/etc/network/interfaces"     # Network config
    "/etc/hosts"                  # Host resolution
    "/etc/hostname"               # Hostname
    "/etc/resolv.conf"            # DNS config
    "/etc/fstab"                  # Mount points
    "/etc/systemd/system"         # Custom services
    "/root/.ssh"                  # SSH keys
    "/var/lib/pve-cluster"        # Cluster config
    "/usr/local/bin"              # Custom scripts
)

# Backup destination:
BACKUP_DIR="/mnt/backup/proxmox-host"
RETENTION_DAYS=90

# Format:
# proxmox-host-config-YYYY-MM-DD-HHMMSS.tar.gz
```

**Features:**
- Timestamped archives
- Compression (gzip or zstd)
- Retention policy (auto-delete old backups)
- Verify backup integrity after creation
- Upload to remote location (optional)

**Remote backup options:**
```bash
# Option 1: Tailscale to NAS
rsync -avz $BACKUP_FILE user@nas:/backups/proxmox/

# Option 2: Rclone to cloud
rclone copy $BACKUP_FILE remote:backups/proxmox/

# Option 3: Restic repository
restic backup $BACKUP_PATHS
```

---

### 3.2 Backup Automation
```bash
# Create systemd timer: /etc/systemd/system/host-backup.timer

# Schedule:
# - Weekly on Sunday at 2 AM (before container updates)
# - Before any major changes (manual trigger)
```

**Pre-change hook:**
```bash
# Create alias for major operations
alias pve-update='backup-host-config.sh --quick && apt update && apt upgrade'
alias pve-kernel-update='backup-host-config.sh --quick && apt install pve-kernel-*'
```

**Testing:**
```bash
# Test backup
./backup-host-config.sh --dry-run
./backup-host-config.sh

# Test restore (on test system)
tar -tzf backup.tar.gz  # List contents
tar -xzf backup.tar.gz -C /tmp/restore-test
```

---

## Phase 4: Storage & Performance Optimization

**Goal:** Automate SSD maintenance and optimize performance

### 4.1 FSTRIM Automation
```bash
# Create script: scripts/proxmox/fstrim-all.sh

# Tasks:
# - Run fstrim on host filesystems
# - Run fstrim inside all running containers
# - Optionally start stopped containers for trim
# - Report space reclaimed per container
# - Total space reclaimed
```

**Implementation:**
```bash
# Host fstrim
fstrim -av

# Container fstrim
for container in $(pct list | awk 'NR>1 {print $1}'); do
    status=$(pct status $container)
    if [[ "$status" == *"running"* ]]; then
        echo "Trimming CT $container..."
        pct exec $container -- fstrim -av
    fi
done
```

**Scheduling:**
```bash
# Weekly on Saturday night
# /etc/systemd/system/fstrim-all.timer
OnCalendar=Sat 23:00
```

---

### 4.2 CPU Governor Management (Optional)
```bash
# Create script: scripts/proxmox/set-cpu-governor.sh

# Options:
# - performance: Maximum performance, high power
# - powersave: Minimum power consumption
# - schedutil: Kernel scheduler decides (default, recommended)
# - ondemand: Legacy dynamic scaling

# Current N100 default is schedutil - probably fine
```

**When to change:**
- **Performance mode:** During heavy workloads, benchmarking
- **Powersave mode:** Idle/vacation periods

**Implementation:**
```bash
# Check current
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Set governor
echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Persist across reboots (systemd service)
```

---

### 4.3 Microcode Updates
```bash
# Create script: scripts/proxmox/update-microcode.sh

# Tasks:
# - Detect CPU vendor (Intel/AMD)
# - Check current microcode revision
# - Fetch latest microcode package
# - Install and verify
# - Require reboot
```

**Intel N100 specific:**
```bash
# Install Intel microcode
apt install intel-microcode

# Check current revision
journalctl -k | grep -i microcode

# After reboot, verify new revision loaded
```

**Scheduling:**
- Run quarterly or after major CPU vulnerability announcements
- Manual trigger before kernel updates

---

## Phase 5: Monitoring & Auto-Recovery

**Goal:** Automatic monitoring and recovery of critical services

### 5.1 Container/VM Health Monitoring
```bash
# Create script: scripts/proxmox/monitor-services.sh

# Features:
# - Tag-based monitoring (only monitor tagged VMs/CTs)
# - Health check methods:
#   - Containers: ping network interface
#   - VMs: QEMU guest agent ping
#   - Application-specific: HTTP endpoint check
# - Auto-restart on failure
# - Notification on restart
# - Cooldown period (don't restart too frequently)
```

**Tagging system:**
```bash
# Tag containers/VMs for monitoring
pct set 100 -tags "mon-restart,critical"
qm set 200 -tags "mon-restart"

# Tag meanings:
# - mon-restart: Auto-restart if unresponsive
# - critical: High-priority notification
# - no-mon: Explicitly exclude from monitoring
```

**Configuration:**
```yaml
# /etc/pve-scripts/monitor-config.yaml
monitoring:
  enabled: true
  check_interval: 300  # 5 minutes
  restart_cooldown: 900  # 15 minutes
  max_restarts: 3  # Within 1 hour

notifications:
  on_restart: true
  on_max_restarts: true
  url: "https://ntfy.sh/homelab-alerts"

health_checks:
  - id: 100
    type: ping
    timeout: 5
  - id: 101
    type: http
    url: "http://localhost:8096/health"
    expected: 200
```

**Implementation as systemd service:**
```bash
# /etc/systemd/system/pve-monitor.service
# - Run continuously
# - Restart on failure
# - Log to journal
```

---

### 5.2 Disk Space Monitoring
```bash
# Create script: scripts/proxmox/check-disk-space.sh

# Monitor:
# - Host: /, /boot, /var/lib/vz
# - Each container's disk usage
# - Alert thresholds: 80% warning, 90% critical
```

**Integration:**
```bash
# Run hourly via systemd timer
# Send notification if threshold exceeded
# Include cleanup recommendations in alert
```

---

## Phase 6: Advanced Features (As Needed)

### 6.1 Hardware Acceleration for Media
```bash
# When deploying Jellyfin/Plex in container:
# - Enable Intel Quick Sync passthrough
# - Mount /dev/dri/renderD128
# - Configure container permissions
# - Install VAAPI drivers in container
```

**Implementation for CT 100 (example):**
```bash
# Add to /etc/pve/lxc/100.conf
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir

# Inside container
apt install intel-media-va-driver-non-free
```

---

### 6.2 Per-Container VPN (Tailscale)
```bash
# For containers that need direct Tailscale access
# - Add TUN device to container config
# - Install Tailscale in container
# - Separate Tailscale node per container
```

**When useful:**
- Exposing specific services on Tailscale
- Container-level network isolation
- Different ACLs per service

---

## Implementation Checklist

### Phase 1: Foundation (Week 1)
- [ ] Create backup of current Proxmox config
- [ ] Run repository fix script
- [ ] Remove subscription nag
- [ ] Clean old kernels
- [ ] Verify system stability
- [ ] Document changes in this repo

### Phase 2: Container Automation (Week 2)
- [ ] Create container update script
- [ ] Test on single container
- [ ] Create systemd service + timer
- [ ] Configure ntfy.sh notifications
- [ ] Test automated run
- [ ] Create container cleanup script

### Phase 3: Backup (Week 3)
- [ ] Create host backup script
- [ ] Test backup creation
- [ ] Test restore procedure
- [ ] Set up remote backup location
- [ ] Create systemd timer
- [ ] Verify first automated backup

### Phase 4: Optimization (Week 4)
- [ ] Create fstrim automation
- [ ] Test fstrim on containers
- [ ] Schedule weekly runs
- [ ] Update microcode
- [ ] Review CPU governor settings
- [ ] Document performance baselines

### Phase 5: Monitoring (Optional)
- [ ] Create monitoring script
- [ ] Configure health checks
- [ ] Tag critical services
- [ ] Test auto-restart functionality
- [ ] Set up disk space alerts
- [ ] Deploy as systemd service

### Phase 6: Advanced (As Needed)
- [ ] Hardware acceleration setup
- [ ] Per-container VPN
- [ ] Custom integrations

---

## Directory Structure

Create organized structure for scripts:

```
homelab/
├── scripts/
│   ├── proxmox/
│   │   ├── fix-repositories.sh
│   │   ├── remove-subscription-nag.sh
│   │   ├── clean-old-kernels.sh
│   │   ├── update-containers.sh
│   │   ├── cleanup-containers.sh
│   │   ├── backup-host-config.sh
│   │   ├── fstrim-all.sh
│   │   ├── monitor-services.sh
│   │   └── utils/
│   │       ├── common.sh        # Shared functions
│   │       └── notifications.sh # Notification helpers
│   └── systemd/
│       ├── container-update.service
│       ├── container-update.timer
│       ├── host-backup.service
│       ├── host-backup.timer
│       ├── fstrim-all.service
│       └── fstrim-all.timer
├── config/
│   └── pve-scripts/
│       ├── container-update.conf
│       ├── monitor-config.yaml
│       └── backup-paths.conf
└── docs/
    ├── proxmox-qol-ideas.md
    └── proxmox-qol-implementation-plan.md  # This file
```

---

## Testing Strategy

### For Each Script:
1. **Dry-run mode**: Preview changes without executing
2. **Single target test**: Test on one container/VM first
3. **Monitor logs**: Watch journalctl during execution
4. **Verify results**: Check that intended changes occurred
5. **Test rollback**: Ensure you can undo changes

### For Automation:
1. **Test service**: `systemctl start service-name`
2. **Check status**: `systemctl status service-name`
3. **View logs**: `journalctl -u service-name -f`
4. **Test timer**: `systemctl list-timers`
5. **Test notification**: Verify ntfy.sh alerts work

---

## Rollback Plans

### Repository Changes
```bash
# Restore original sources
cp /backup/sources.list.d/* /etc/apt/sources.list.d/
apt update
```

### Script Failures
- All scripts should exit cleanly on error
- Use `set -e` for automatic error handling
- Create backups before making changes
- Log all operations for troubleshooting

### Systemd Services
```bash
# Stop and disable service
systemctl stop service-name
systemctl disable service-name

# Remove timer
systemctl stop service-name.timer
systemctl disable service-name.timer
```

---

## Success Metrics

After full implementation, you should have:

- ✅ Zero subscription nag popups
- ✅ Automated weekly container updates
- ✅ Automated weekly host config backups
- ✅ Automated weekly SSD maintenance (fstrim)
- ✅ Clean `/boot` partition (old kernels removed)
- ✅ Notification system for important events
- ✅ Monitoring for critical services (optional)
- ✅ All scripts version controlled in this repo
- ✅ Documentation for maintenance procedures

---

## Maintenance Schedule (After Implementation)

**Daily:**
- Monitoring checks (automatic)

**Weekly:**
- Container updates (automatic, Sunday 3 AM)
- Host config backup (automatic, Sunday 2 AM)
- FSTRIM (automatic, Saturday 11 PM)

**Monthly:**
- Container cleanup (automatic)
- Review backup retention
- Check disk space trends

**Quarterly:**
- Microcode updates
- Kernel updates (pin if needed)
- Review and update scripts
- Test restore procedures

**Annually:**
- Full disaster recovery test
- Review and update documentation
- Audit automated tasks

---

## Notes

- All scripts should be idempotent (safe to run multiple times)
- Use version control for all scripts and configs
- Test on non-production system when possible
- Keep this plan updated as you implement
- Document any deviations from the plan
- Share learnings in journal entries

---

## Resources

- Original scripts: `/tmp/ProxmoxVE/` (temporary)
- Community repo: https://github.com/community-scripts/ProxmoxVE
- Proxmox docs: https://pve.proxmox.com/pve-docs/
- Systemd timers: `man systemd.timer`
- Ntfy.sh: https://ntfy.sh
