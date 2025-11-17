# Proxmox Quality of Life - Implementation Plan

This is an implementation plan for Proxmox homelab quality of life improvements. All automation is implemented as **Ansible roles** to integrate with existing IaC infrastructure.

**Scope**: Phases 1-4 (Foundation, Container Management, Host Backup, Storage Optimization)  
**Out of Scope**: Notifications (separate project), Monitoring (Phase 5, separate project)

---

## Phase 1: Post-Install Configuration & Cleanup

**Goal**: Fix repositories, remove subscription nag, clean up old kernels  
**Implementation**: New Ansible role `proxmox_host_setup`

### 1.1 Repository Configuration

**Ansible Tasks**:
```yaml
# ansible/roles/proxmox_host_setup/tasks/repositories.yml

- name: Backup existing apt sources
  ansible.builtin.copy:
    src: /etc/apt/sources.list.d/
    dest: /root/apt-sources-backup-{{ ansible_date_time.date }}/
    remote_src: true
    mode: preserve

- name: Disable pve-enterprise repository
  ansible.builtin.file:
    path: /etc/apt/sources.list.d/pve-enterprise.list
    state: absent

- name: Enable pve-no-subscription repository
  ansible.builtin.apt_repository:
    repo: "deb http://download.proxmox.com/debian/pve {{ ansible_distribution_release }} pve-no-subscription"
    filename: pve-no-subscription
    state: present
```

**Testing**:
```bash
ansible-playbook playbooks/proxmox-host.yml --tags repositories --check
ansible-playbook playbooks/proxmox-host.yml --tags repositories
ssh cuiv@homelab "apt update"  # Verify no errors
```

**Rollback**:
```bash
ssh cuiv@homelab "cp -r /root/apt-sources-backup-*/* /etc/apt/sources.list.d/"
```

---

### 1.2 Remove Subscription Nag

**Ansible Tasks**:
```yaml
# ansible/roles/proxmox_host_setup/tasks/remove-nag.yml

- name: Deploy nag removal script
  ansible.builtin.template:
    src: pve-remove-nag.sh.j2
    dest: /usr/local/bin/pve-remove-nag.sh
    mode: '0755'

- name: Run nag removal script
  ansible.builtin.command: /usr/local/bin/pve-remove-nag.sh
  changed_when: true

- name: Create APT hook to re-run after updates
  ansible.builtin.copy:
    dest: /etc/apt/apt.conf.d/99-pve-no-nag
    content: |
      DPkg::Post-Invoke { "/usr/local/bin/pve-remove-nag.sh || true"; };
    mode: '0644'
```

**Testing**:
- Clear browser cache (Ctrl+Shift+R)
- Log out and back in to Proxmox UI
- Verify no subscription popup

**Rollback**:
```bash
ssh cuiv@homelab "apt reinstall proxmox-widget-toolkit"
```

---

### 1.3 Kernel Cleanup (Automatic)

**Ansible Tasks**:
```yaml
# ansible/roles/proxmox_host_setup/tasks/kernel-cleanup.yml

- name: Get current running kernel
  ansible.builtin.command: uname -r
  register: current_kernel
  changed_when: false

- name: List all installed PVE kernels
  ansible.builtin.shell: |
    dpkg --list | grep 'pve-kernel-[0-9]' | awk '{print $2}' | sort -V
  register: installed_kernels
  changed_when: false

- name: Identify kernels to remove (keep current + 1 previous)
  ansible.builtin.set_fact:
    kernels_to_remove: "{{ installed_kernels.stdout_lines[:-2] }}"
  when: installed_kernels.stdout_lines | length > 2

- name: Remove old kernels
  ansible.builtin.apt:
    name: "{{ kernels_to_remove }}"
    state: absent
    purge: true
  when: kernels_to_remove is defined and kernels_to_remove | length > 0
  notify: Update grub

- name: Show disk space after cleanup
  ansible.builtin.command: df -h /boot
  register: boot_space
  changed_when: false

- name: Display boot partition space
  ansible.builtin.debug:
    var: boot_space.stdout_lines
```

**Safety**: Always keeps current kernel + 1 previous for rollback via GRUB menu.

---

## Phase 2: Automated Container Management

**Goal**: Automate container updates with active-use detection  
**Implementation**: New Ansible role `proxmox_container_updates`

### 2.1 Active-Use Detection System

**Design**: Hybrid approach with process detection + lock file override

```yaml
# ansible/inventory/group_vars/proxmox_host.yml

# Active-use detection configuration
container_update_checks:
  # Process patterns that indicate container is busy
  busy_processes:
    - pattern: "ffmpeg|HandBrakeCLI|av1an"
      description: "video transcoding"
    - pattern: "makemkvcon"
      description: "disc ripping"
    - pattern: "filebot"
      description: "media organization"

  # Lock file for manual override (touch this to prevent updates)
  lock_file: "/var/run/no-container-updates.lock"

  # Per-container overrides (optional)
  container_overrides:
    # Example: always skip test container
    # 199:
    #   skip: true
    #   reason: "test container"

# Container update settings
container_update_config:
  # Containers to always exclude from updates
  exclude_ctids: []

  # Auto-start stopped containers for updates, then stop again
  auto_start_for_update: true

  # Create snapshot before updating (if storage supports it)
  snapshot_before_update: false

  # Log file location
  log_file: "/var/log/container-updates.log"
```

### 2.2 Update Script Template

```bash
# ansible/roles/proxmox_container_updates/templates/update-containers.sh.j2
#!/bin/bash
set -euo pipefail

LOG_FILE="{{ container_update_config.log_file }}"
LOCK_FILE="{{ container_update_checks.lock_file }}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

# Check for global lock file (manual override)
if [[ -f "$LOCK_FILE" ]]; then
    log "SKIP: Lock file exists at $LOCK_FILE"
    exit 0
fi

# Check if any container has busy processes
check_container_busy() {
    local ctid=$1
    local status

    status=$(pct status "$ctid" 2>/dev/null | awk '{print $2}')
    if [[ "$status" != "running" ]]; then
        return 1  # Not running, not busy
    fi

    # Check each busy process pattern
{% for check in container_update_checks.busy_processes %}
    if pct exec "$ctid" -- pgrep -f "{{ check.pattern }}" &>/dev/null; then
        log "SKIP CT$ctid: {{ check.description }} in progress"
        return 0  # Busy
    fi
{% endfor %}

    return 1  # Not busy
}

# Get distro type for container
get_container_distro() {
    local ctid=$1
    if pct exec "$ctid" -- test -f /etc/debian_version 2>/dev/null; then
        echo "debian"
    elif pct exec "$ctid" -- test -f /etc/alpine-release 2>/dev/null; then
        echo "alpine"
    elif pct exec "$ctid" -- test -f /etc/arch-release 2>/dev/null; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# Update a single container
update_container() {
    local ctid=$1
    local distro

    distro=$(get_container_distro "$ctid")
    log "Updating CT$ctid ($distro)..."

    case "$distro" in
        debian)
            pct exec "$ctid" -- bash -c "apt-get update && apt-get dist-upgrade -y && apt-get autoremove -y"
            ;;
        alpine)
            pct exec "$ctid" -- apk upgrade --no-cache
            ;;
        arch)
            pct exec "$ctid" -- pacman -Syu --noconfirm
            ;;
        *)
            log "WARNING: Unknown distro for CT$ctid, skipping"
            return 1
            ;;
    esac
}

log "=== Container Update Run Started ==="

# Get list of all containers
CONTAINERS=$(pct list | awk 'NR>1 {print $1}')

for ctid in $CONTAINERS; do
    # Check exclusion list
{% if container_update_config.exclude_ctids | length > 0 %}
    if [[ " {{ container_update_config.exclude_ctids | join(' ') }} " =~ " $ctid " ]]; then
        log "SKIP CT$ctid: In exclusion list"
        continue
    fi
{% endif %}

    # Check if busy
    if check_container_busy "$ctid"; then
        continue
    fi

    # Check if running
    status=$(pct status "$ctid" 2>/dev/null | awk '{print $2}')
    was_stopped=false

    if [[ "$status" != "running" ]]; then
{% if container_update_config.auto_start_for_update %}
        log "Starting CT$ctid for update..."
        pct start "$ctid"
        sleep 5
        was_stopped=true
{% else %}
        log "SKIP CT$ctid: Not running"
        continue
{% endif %}
    fi

    # Perform update
    if update_container "$ctid"; then
        log "SUCCESS: CT$ctid updated"
    else
        log "ERROR: CT$ctid update failed"
    fi

    # Stop if we started it
    if [[ "$was_stopped" == "true" ]]; then
        log "Stopping CT$ctid (was stopped before update)"
        pct shutdown "$ctid"
    fi
done

log "=== Container Update Run Completed ==="
```

### 2.3 Systemd Timer for Automation

```yaml
# ansible/roles/proxmox_container_updates/tasks/systemd.yml

- name: Deploy container update script
  ansible.builtin.template:
    src: update-containers.sh.j2
    dest: /usr/local/bin/update-containers.sh
    mode: '0755'

- name: Create systemd service for container updates
  ansible.builtin.copy:
    dest: /etc/systemd/system/container-update.service
    content: |
      [Unit]
      Description=Update all LXC containers
      After=network.target

      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/update-containers.sh
      StandardOutput=journal
      StandardError=journal
    mode: '0644'
  notify: Reload systemd

- name: Create systemd timer for weekly updates
  ansible.builtin.copy:
    dest: /etc/systemd/system/container-update.timer
    content: |
      [Unit]
      Description=Weekly container updates

      [Timer]
      OnCalendar=Sun 03:00
      Persistent=true
      RandomizedDelaySec=300

      [Install]
      WantedBy=timers.target
    mode: '0644'
  notify: Reload systemd

- name: Enable container update timer
  ansible.builtin.systemd:
    name: container-update.timer
    enabled: true
    state: started
```

### 2.4 Container Cleanup (Monthly)

```yaml
# ansible/roles/proxmox_container_updates/tasks/cleanup.yml

- name: Deploy container cleanup script
  ansible.builtin.template:
    src: cleanup-containers.sh.j2
    dest: /usr/local/bin/cleanup-containers.sh
    mode: '0755'

- name: Create systemd timer for monthly cleanup
  ansible.builtin.copy:
    dest: /etc/systemd/system/container-cleanup.timer
    content: |
      [Unit]
      Description=Monthly container cleanup

      [Timer]
      OnCalendar=monthly
      Persistent=true

      [Install]
      WantedBy=timers.target
    mode: '0644'
```

**Cleanup script clears**:
- `/var/cache/apt/` (Debian/Ubuntu)
- `/var/log/*.gz`, `/var/log/*.old` (rotated logs)
- `/tmp/*` (temp files)
- Package manager caches

---

## Phase 3: Host Configuration Backup

**Goal**: Automated backups of Proxmox host config, integrated with existing restic infrastructure  
**Implementation**: New Ansible role `proxmox_host_backup`

### 3.1 Architecture

```
Proxmox Host                     Backup Container (CT300)
     |                                    |
     | Weekly cron job                    |
     | creates tar.gz archive             |
     |                                    |
     v                                    |
/mnt/storage/backups/proxmox-host/       |
     |                                    |
     +------------------------------------+
                      |
                      v
              Existing restic backup
              (backs up /mnt/storage)
                      |
                      v
                 Backblaze B2
```

**Why this works**:
- Host stays minimal (just a shell script + cron)
- Archives land in mergerfs pool
- Your existing restic policy already backs up `/mnt/storage`
- Automatic offsite backup to B2 with deduplication

### 3.2 Host Backup Script

```bash
# ansible/roles/proxmox_host_backup/templates/backup-host-config.sh.j2
#!/bin/bash
set -euo pipefail

BACKUP_DIR="{{ host_backup_destination }}"
TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
BACKUP_NAME="proxmox-host-config-${TIMESTAMP}.tar.gz"
RETENTION_DAYS={{ host_backup_retention_days }}

# Paths to backup
BACKUP_PATHS=(
    "/etc/pve"                    # Proxmox config (VMs, containers, cluster)
    "/etc/network/interfaces"     # Network config
    "/etc/hosts"                  # Host resolution
    "/etc/hostname"               # Hostname
    "/etc/resolv.conf"            # DNS config
    "/etc/fstab"                  # Mount points
    "/etc/modprobe.d"             # Kernel modules
    "/etc/systemd/system"         # Custom services
    "/root/.ssh"                  # SSH keys
    "/usr/local/bin"              # Custom scripts (including this one)
    "/etc/apt/sources.list.d"     # APT repositories
    "/etc/apt/apt.conf.d"         # APT configuration
)

echo "=== Proxmox Host Config Backup ==="
echo "Timestamp: $TIMESTAMP"
echo "Destination: $BACKUP_DIR/$BACKUP_NAME"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Create archive
echo "Creating archive..."
tar -czf "$BACKUP_DIR/$BACKUP_NAME" \
    --ignore-failed-read \
    --warning=no-file-changed \
    "${BACKUP_PATHS[@]}" 2>/dev/null || true

# Verify archive
echo "Verifying archive..."
tar -tzf "$BACKUP_DIR/$BACKUP_NAME" > /dev/null
ARCHIVE_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
echo "Archive created: $ARCHIVE_SIZE"

# Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "proxmox-host-config-*.tar.gz" -mtime +$RETENTION_DAYS -delete

# Show current backups
echo "Current backups:"
ls -lh "$BACKUP_DIR"/*.tar.gz | tail -5

echo "=== Backup Complete ==="
```

### 3.3 Ansible Role Configuration

```yaml
# ansible/roles/proxmox_host_backup/defaults/main.yml

# Where to store host config backups (should be on mergerfs pool)
host_backup_destination: "/mnt/storage/backups/proxmox-host"

# How long to keep local archives (restic handles long-term retention)
host_backup_retention_days: 30

# Schedule: Weekly on Sunday at 2 AM (before container updates at 3 AM)
host_backup_schedule: "Sun 02:00"
```

```yaml
# ansible/roles/proxmox_host_backup/tasks/main.yml

- name: Create backup destination directory
  ansible.builtin.file:
    path: "{{ host_backup_destination }}"
    state: directory
    mode: '0750'
    owner: root
    group: root

- name: Deploy host backup script
  ansible.builtin.template:
    src: backup-host-config.sh.j2
    dest: /usr/local/bin/backup-host-config.sh
    mode: '0755'

- name: Create systemd service for host backup
  ansible.builtin.copy:
    dest: /etc/systemd/system/host-backup.service
    content: |
      [Unit]
      Description=Backup Proxmox host configuration
      After=mnt-storage.mount

      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/backup-host-config.sh
      StandardOutput=journal
      StandardError=journal
    mode: '0644'
  notify: Reload systemd

- name: Create systemd timer for host backup
  ansible.builtin.copy:
    dest: /etc/systemd/system/host-backup.timer
    content: |
      [Unit]
      Description=Weekly Proxmox host config backup

      [Timer]
      OnCalendar={{ host_backup_schedule }}
      Persistent=true

      [Install]
      WantedBy=timers.target
    mode: '0644'
  notify: Reload systemd

- name: Enable host backup timer
  ansible.builtin.systemd:
    name: host-backup.timer
    enabled: true
    state: started
```

### 3.4 Restore Procedure

```bash
# 1. Fresh install Proxmox VE (same version if possible)

# 2. Mount storage pool
mount /mnt/storage

# 3. Extract backup to temp location
mkdir /tmp/restore
tar -xzf /mnt/storage/backups/proxmox-host/proxmox-host-config-YYYY-MM-DD-HHMMSS.tar.gz -C /tmp/restore

# 4. SELECTIVELY restore configs (DO NOT blindly copy)
# Compare each file before overwriting:
diff /tmp/restore/etc/pve/storage.cfg /etc/pve/storage.cfg
diff /tmp/restore/etc/network/interfaces /etc/network/interfaces
diff /tmp/restore/etc/fstab /etc/fstab

# 5. Restore VM/CT configs
cp -r /tmp/restore/etc/pve/lxc/* /etc/pve/lxc/
cp -r /tmp/restore/etc/pve/qemu-server/* /etc/pve/qemu-server/

# 6. Reboot and verify
reboot
```

---

## Phase 4: Storage & Performance Optimization

**Goal**: Automate SSD maintenance (FSTRIM)  
**Implementation**: Add to `proxmox_host_setup` role

### 4.1 FSTRIM Automation

```bash
# ansible/roles/proxmox_host_setup/templates/fstrim-all.sh.j2
#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/fstrim.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

log "=== FSTRIM Run Started ==="

# Trim host filesystems
log "Trimming host filesystems..."
fstrim -av 2>&1 | tee -a "$LOG_FILE"

# Trim each running container
log "Trimming container filesystems..."
for ctid in $(pct list | awk 'NR>1 {print $1}'); do
    status=$(pct status "$ctid" 2>/dev/null | awk '{print $2}')
    if [[ "$status" == "running" ]]; then
        log "Trimming CT$ctid..."
        pct exec "$ctid" -- fstrim -av 2>&1 | tee -a "$LOG_FILE" || log "WARNING: fstrim failed for CT$ctid"
    fi
done

log "=== FSTRIM Run Completed ==="
```

### 4.2 Systemd Timer

```yaml
# ansible/roles/proxmox_host_setup/tasks/fstrim.yml

- name: Deploy fstrim script
  ansible.builtin.template:
    src: fstrim-all.sh.j2
    dest: /usr/local/bin/fstrim-all.sh
    mode: '0755'

- name: Create systemd service for fstrim
  ansible.builtin.copy:
    dest: /etc/systemd/system/fstrim-all.service
    content: |
      [Unit]
      Description=Trim all filesystems (host + containers)

      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/fstrim-all.sh
      StandardOutput=journal
      StandardError=journal
    mode: '0644'
  notify: Reload systemd

- name: Create systemd timer for weekly fstrim
  ansible.builtin.copy:
    dest: /etc/systemd/system/fstrim-all.timer
    content: |
      [Unit]
      Description=Weekly FSTRIM for all filesystems

      [Timer]
      OnCalendar=Sat 23:00
      Persistent=true

      [Install]
      WantedBy=timers.target
    mode: '0644'
  notify: Reload systemd

- name: Enable fstrim timer
  ansible.builtin.systemd:
    name: fstrim-all.timer
    enabled: true
    state: started
```

---

## Directory Structure

```
ansible/
├── inventory/
│   └── group_vars/
│       └── proxmox_host.yml          # Container update config, etc.
├── playbooks/
│   └── proxmox-host.yml              # Main playbook for host setup
└── roles/
    ├── proxmox_host_setup/           # Phase 1 & 4
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml              # reload systemd, update grub
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── repositories.yml
    │   │   ├── remove-nag.yml
    │   │   ├── kernel-cleanup.yml
    │   │   └── fstrim.yml
    │   └── templates/
    │       ├── pve-remove-nag.sh.j2
    │       └── fstrim-all.sh.j2
    ├── proxmox_container_updates/    # Phase 2
    │   ├── defaults/
    │   │   └── main.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── update-script.yml
    │   │   ├── cleanup-script.yml
    │   │   └── systemd.yml
    │   └── templates/
    │       ├── update-containers.sh.j2
    │       └── cleanup-containers.sh.j2
    └── proxmox_host_backup/          # Phase 3
        ├── defaults/
        │   └── main.yml
        ├── handlers/
        │   └── main.yml
        ├── tasks/
        │   └── main.yml
        └── templates/
            └── backup-host-config.sh.j2
```

---

## Implementation Checklist

### Phase 1: Foundation
- [ ] Create `proxmox_host_setup` role
- [ ] Implement repository configuration tasks
- [ ] Implement subscription nag removal
- [ ] Implement automatic kernel cleanup
- [ ] Create `proxmox-host.yml` playbook
- [ ] Test with `--check` (dry-run)
- [ ] Apply to Proxmox host
- [ ] Verify system stability

### Phase 2: Container Management
- [ ] Add container update config to `proxmox_host.yml`
- [ ] Create `proxmox_container_updates` role
- [ ] Implement active-use detection logic
- [ ] Implement update script with distro detection
- [ ] Implement cleanup script
- [ ] Deploy systemd timers
- [ ] Test manual lock file override
- [ ] Test on single container first
- [ ] Enable weekly automation

### Phase 3: Host Backup
- [ ] Create `proxmox_host_backup` role
- [ ] Implement backup script
- [ ] Deploy systemd timer
- [ ] Verify backups land in `/mnt/storage/backups/proxmox-host/`
- [ ] Verify existing restic picks them up (check B2)
- [ ] Document restore procedure
- [ ] Test restore on CTID 199

### Phase 4: Storage Optimization
- [ ] Implement fstrim script
- [ ] Deploy systemd timer
- [ ] Test manual run
- [ ] Verify logs in `/var/log/fstrim.log`

---

## Testing Strategy

### For Each Role:
```bash
# Syntax check
ansible-playbook playbooks/proxmox-host.yml --syntax-check

# Dry run
ansible-playbook playbooks/proxmox-host.yml --check --diff

# Run specific tags
ansible-playbook playbooks/proxmox-host.yml --tags repositories
ansible-playbook playbooks/proxmox-host.yml --tags kernel-cleanup

# Full run
ansible-playbook playbooks/proxmox-host.yml
```

### For Active-Use Detection:
```bash
# Test lock file
ssh cuiv@homelab "sudo touch /var/run/no-container-updates.lock"
ssh cuiv@homelab "sudo /usr/local/bin/update-containers.sh"  # Should skip all
ssh cuiv@homelab "sudo rm /var/run/no-container-updates.lock"

# Test process detection
ssh cuiv@homelab "sudo pct exec 304 -- sleep 3600 &"  # Simulate busy process
ssh cuiv@homelab "sudo /usr/local/bin/update-containers.sh"  # Should skip 304
```

### For Systemd Timers:
```bash
# List all timers
ssh cuiv@homelab "systemctl list-timers"

# Test manual trigger
ssh cuiv@homelab "sudo systemctl start container-update.service"
ssh cuiv@homelab "journalctl -u container-update -f"
```

---

## Maintenance Schedule (After Implementation)

**Weekly (Automated)**:
- Saturday 23:00 - FSTRIM all filesystems
- Sunday 02:00 - Host config backup
- Sunday 03:00 - Container updates (if not busy)

**Monthly (Automated)**:
- Container cleanup (clear caches, old logs)

**Quarterly (Manual)**:
- Review kernel updates
- Check backup retention
- Test restore procedure

---

## Success Metrics

- [ ] No subscription nag in Proxmox UI
- [ ] `/boot` partition has adequate free space
- [ ] Container updates run weekly without intervention
- [ ] Updates skip containers with active jobs (transcoding, ripping, etc.)
- [ ] Host configs backed up to mergerfs pool
- [ ] Host config archives appear in B2 via restic
- [ ] FSTRIM runs weekly on all filesystems
- [ ] All automation is version-controlled in Ansible
- [ ] Can restore Proxmox config from backup

---

## Notes

- All scripts idempotent (safe to run multiple times)
- Active-use detection is extensible (add new process patterns in vars)
- Lock file provides manual override for maintenance windows
- Host backup integrates with existing restic infrastructure (no new tools on host)
- Notifications deferred to separate project (can add hooks later)
- Monitoring deferred to Phase 5 (separate project)

---

## References

- Proxmox docs: https://pve.proxmox.com/pve-docs/
- Systemd timers: `man systemd.timer`
- Community backup scripts: https://github.com/DerDanilo/proxmox-stuff
- Your existing restic role: `ansible/roles/restic_backup/`
