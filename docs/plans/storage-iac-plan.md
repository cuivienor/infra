# Storage Infrastructure as Code Plan

**Created**: 2025-11-11  
**Purpose**: Automate MergerFS + SnapRAID configuration for disaster recovery

---

## Current State Analysis

### What You Have Now

**MergerFS Pool**:
- ✅ Installed: `mergerfs v2.40.2`
- ✅ Configured: `/etc/fstab` entry with proper options
- ✅ Working: 35TB pool (13% used) mounted at `/mnt/storage`
- ✅ 3x data disks + 1x parity disk

**SnapRAID**:
- ⚠️ Binary: Not currently installed/accessible
- ✅ Data: Parity file exists (`/mnt/parity/snapraid.parity` - 3.1TB)
- ✅ Content files: Present on all disks (`.snapraid.content`)
- ✅ Last sync: January 25, 2025 (recent!)
- ⚠️ Config: `/etc/snapraid.conf` missing
- ⚠️ Automation: No cron/systemd timers currently

### Storage Layout

```
Data Disks (merged into /mnt/storage):
├── /mnt/disk1 → /dev/sdc1 (WD101EDBZ) - 9.1TB - 48% used (4.1TB)
├── /mnt/disk2 → /dev/sdd1 (ST10000DM) - 9.1TB - 1% used (205MB)
└── /mnt/disk3 → /dev/sdb1 (WD180EDGZ) - 17TB - 1% used (23GB)

Parity Disk (SnapRAID):
└── /mnt/parity → /dev/sda1 (WD180EDGZ) - 17TB - 20% used (3.1TB)

Total Pool: 35TB (3x data) + 17TB (parity)
```

### Disk Identification (by-id)

```
/mnt/disk1  → ata-WDC_WD101EDBZ-11B1DA0_VCHLGZTP-part1
/mnt/disk2  → ata-ST10000DM0004-1ZC101_ZA2DWAHC-part1
/mnt/disk3  → ata-WDC_WD180EDGZ-11B2DA0_3FKXJ3UV-part1
/mnt/parity → ata-WDC_WD180EDGZ-11B2DA0_3FKJMTSV-part1
```

### Current fstab Configuration

```bash
# Data disks
/dev/disk/by-id/ata-WDC_WD101EDBZ-11B1DA0_VCHLGZTP-part1 /mnt/disk1   ext4 defaults 0 0
/dev/disk/by-id/ata-ST10000DM0004-1ZC101_ZA2DWAHC-part1 /mnt/disk2 ext4 defaults 0 0
/dev/disk/by-id/ata-WDC_WD180EDGZ-11B2DA0_3FKXJ3UV-part1 /mnt/disk3 ext4 defaults 0 0

# Parity disk
/dev/disk/by-id/ata-WDC_WD180EDGZ-11B2DA0_3FKJMTSV-part1 /mnt/parity ext4 defaults 0 0

# MergerFS pool
/mnt/disk* /mnt/storage fuse.mergerfs defaults,nonempty,allow_other,use_ino,cache.files=off,moveonenospc=true,dropcacheonclose=true,minfreespace=200G,fsname=mergerfs 0 0
```

### MergerFS Options Analysis

| Option | Purpose | Perfect Media Server Recommendation |
|--------|---------|-------------------------------------|
| `defaults` | Standard mount options | ✅ Good |
| `nonempty` | Allow mounting over non-empty dir | ✅ Good |
| `allow_other` | Allow non-root access | ✅ Required |
| `use_ino` | Use proper inode values | ✅ Good |
| `cache.files=off` | Disable file caching | ✅ Good for large files |
| `moveonenospc=true` | Move files when disk full | ✅ Perfect for media |
| `dropcacheonclose=true` | Drop cache when file closed | ✅ Good |
| `minfreespace=200G` | Reserve space threshold | ✅ Good value |
| `fsname=mergerfs` | Filesystem name | ✅ Good for identification |
| **Missing**: `category.create=mfs` | Create policy | ⚠️ Consider adding |

**Recommendation**: Your current config is solid! Consider adding `category.create=mfs` if you want files spread across disks rather than path preservation.

---

## Required SnapRAID Configuration

Based on your discovered setup, here's what your `/etc/snapraid.conf` should look like:

```conf
# SnapRAID configuration file

# Parity file location
parity /mnt/parity/snapraid.parity

# Content file locations (stored on each data disk for redundancy)
content /mnt/disk1/.snapraid.content
content /mnt/disk2/.snapraid.content
content /mnt/disk3/.snapraid.content

# Data disks
data d1 /mnt/disk1
data d2 /mnt/disk2
data d3 /mnt/disk3

# Excludes
exclude *.unrecoverable
exclude /tmp/
exclude /lost+found/
exclude downloads/
exclude appdata/
exclude *.!sync

# Exclude all hidden files and directories (eg. AppleDouble / Thumbnails)
exclude *.DS_Store
exclude /.Trashes
exclude /.fseventsd
exclude /.Spotlight-V100
exclude /.TemporaryItems
exclude /.DocumentRevisions-V100
exclude /.AppleDB
exclude /.AppleDesktop
exclude /Network Trash Folder
exclude /Temporary Items

# Exclude container/VM data
exclude /mnt/disk*/lxc/
exclude /mnt/disk*/images/

# Block size (default 256KB is good for most use cases)
block_size 256

# Hash algorithm (blake2 is fastest, most modern)
hash blake2

# Auto-save scrub status
autosave 500
```

---

## Ansible Role Structure

### Role: `proxmox_storage`

```
ansible/roles/proxmox_storage/
├── defaults/
│   └── main.yml          # Default variables
├── tasks/
│   ├── main.yml          # Main task orchestration
│   ├── install.yml       # Install mergerfs/snapraid
│   ├── disks.yml         # Create mount points, fstab entries
│   ├── mergerfs.yml      # MergerFS configuration
│   ├── snapraid.yml      # SnapRAID configuration
│   └── permissions.yml   # Set ownership/permissions
├── templates/
│   ├── fstab.j2          # fstab template
│   └── snapraid.conf.j2  # SnapRAID config template
├── files/
│   └── snapraid-runner.sh  # SnapRAID automation script
└── handlers/
    └── main.yml          # Handlers for remounting, etc.
```

---

## Implementation Plan

### Phase 1: Ansible Role Development

**Step 1**: Create role structure
```bash
cd ~/dev/homelab-notes
mkdir -p ansible/roles/proxmox_storage/{defaults,tasks,templates,files,handlers}
```

**Step 2**: Define variables in `defaults/main.yml`
```yaml
---
# Storage configuration
storage_disks:
  - name: disk1
    device: /dev/disk/by-id/ata-WDC_WD101EDBZ-11B1DA0_VCHLGZTP-part1
    mount: /mnt/disk1
    fstype: ext4
    opts: defaults
  - name: disk2
    device: /dev/disk/by-id/ata-ST10000DM0004-1ZC101_ZA2DWAHC-part1
    mount: /mnt/disk2
    fstype: ext4
    opts: defaults
  - name: disk3
    device: /dev/disk/by-id/ata-WDC_WD180EDGZ-11B2DA0_3FKXJ3UV-part1
    mount: /mnt/disk3
    fstype: ext4
    opts: defaults

storage_parity_disk:
  device: /dev/disk/by-id/ata-WDC_WD180EDGZ-11B2DA0_3FKJMTSV-part1
  mount: /mnt/parity
  fstype: ext4
  opts: defaults

# MergerFS configuration
mergerfs_version: "2.40.2"
mergerfs_pool_path: /mnt/storage
mergerfs_source_dirs: /mnt/disk*
mergerfs_opts: "defaults,nonempty,allow_other,use_ino,cache.files=off,moveonenospc=true,dropcacheonclose=true,category.create=mfs,minfreespace=200G,fsname=mergerfs"

# SnapRAID configuration
snapraid_version: "12.3"  # Current stable version
snapraid_parity_file: /mnt/parity/snapraid.parity
snapraid_content_files:
  - /mnt/disk1/.snapraid.content
  - /mnt/disk2/.snapraid.content
  - /mnt/disk3/.snapraid.content
snapraid_block_size: 256
snapraid_hash: blake2
snapraid_autosave: 500

# SnapRAID sync schedule
snapraid_sync_enabled: true
snapraid_sync_schedule: "0 3 * * *"  # 3 AM daily
snapraid_scrub_enabled: true
snapraid_scrub_schedule: "0 4 * * 1"  # 4 AM Monday weekly
snapraid_scrub_percent: 8  # Scrub 8% of array per run

# Media user
media_user: media
media_uid: 1000
media_gid: 1000
```

**Step 3**: Create main tasks file `tasks/main.yml`
```yaml
---
- name: Install storage packages
  include_tasks: install.yml
  tags: [install, storage]

- name: Configure data disks
  include_tasks: disks.yml
  tags: [disks, storage]

- name: Configure MergerFS
  include_tasks: mergerfs.yml
  tags: [mergerfs, storage]

- name: Configure SnapRAID
  include_tasks: snapraid.yml
  tags: [snapraid, storage]

- name: Set permissions
  include_tasks: permissions.yml
  tags: [permissions, storage]
```

**Step 4**: Install packages `tasks/install.yml`
```yaml
---
- name: Check if mergerfs is installed
  command: dpkg -l mergerfs
  register: mergerfs_check
  failed_when: false
  changed_when: false

- name: Install mergerfs from GitHub releases
  block:
    - name: Download mergerfs .deb
      get_url:
        url: "https://github.com/trapexit/mergerfs/releases/download/{{ mergerfs_version }}/mergerfs_{{ mergerfs_version }}.debian-bookworm_amd64.deb"
        dest: "/tmp/mergerfs_{{ mergerfs_version }}.deb"
        mode: '0644'

    - name: Install mergerfs package
      apt:
        deb: "/tmp/mergerfs_{{ mergerfs_version }}.deb"
        state: present

    - name: Clean up downloaded package
      file:
        path: "/tmp/mergerfs_{{ mergerfs_version }}.deb"
        state: absent
  when: mergerfs_check.rc != 0

- name: Check if snapraid is installed
  command: which snapraid
  register: snapraid_check
  failed_when: false
  changed_when: false

- name: Install snapraid from GitHub
  block:
    - name: Install build dependencies
      apt:
        name:
          - gcc
          - make
        state: present

    - name: Download snapraid source
      get_url:
        url: "https://github.com/amadvance/snapraid/releases/download/v{{ snapraid_version }}/snapraid-{{ snapraid_version }}.tar.gz"
        dest: "/tmp/snapraid-{{ snapraid_version }}.tar.gz"
        mode: '0644'

    - name: Extract snapraid source
      unarchive:
        src: "/tmp/snapraid-{{ snapraid_version }}.tar.gz"
        dest: /tmp/
        remote_src: yes

    - name: Configure snapraid
      command: ./configure
      args:
        chdir: "/tmp/snapraid-{{ snapraid_version }}"
        creates: "/tmp/snapraid-{{ snapraid_version }}/Makefile"

    - name: Build snapraid
      command: make
      args:
        chdir: "/tmp/snapraid-{{ snapraid_version }}"
        creates: "/tmp/snapraid-{{ snapraid_version }}/snapraid"

    - name: Install snapraid
      command: make install
      args:
        chdir: "/tmp/snapraid-{{ snapraid_version }}"
        creates: /usr/local/bin/snapraid

    - name: Clean up build files
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - "/tmp/snapraid-{{ snapraid_version }}.tar.gz"
        - "/tmp/snapraid-{{ snapraid_version }}"
  when: snapraid_check.rc != 0
```

**Step 5**: Configure disks `tasks/disks.yml`
```yaml
---
- name: Create mount point directories
  file:
    path: "{{ item.mount }}"
    state: directory
    mode: '0755'
  loop: "{{ storage_disks + [storage_parity_disk] }}"

- name: Create fstab entries from template
  template:
    src: fstab.j2
    dest: /etc/fstab.d/storage
    mode: '0644'
  notify: reload fstab

- name: Append storage fstab to main fstab
  blockinfile:
    path: /etc/fstab
    block: "{{ lookup('template', 'fstab.j2') }}"
    marker: "# {mark} ANSIBLE MANAGED - STORAGE DISKS"
    create: no
  notify: mount disks

- name: Mount all storage disks
  command: mount -a
  args:
    warn: false
  changed_when: false
```

**Step 6**: Configure MergerFS `tasks/mergerfs.yml`
```yaml
---
- name: Verify mergerfs is installed
  command: which mergerfs
  register: mergerfs_bin
  failed_when: mergerfs_bin.rc != 0
  changed_when: false

- name: Create mergerfs mount point
  file:
    path: "{{ mergerfs_pool_path }}"
    state: directory
    mode: '0755'

- name: Add mergerfs entry to fstab
  mount:
    path: "{{ mergerfs_pool_path }}"
    src: "{{ mergerfs_source_dirs }}"
    fstype: fuse.mergerfs
    opts: "{{ mergerfs_opts }}"
    state: mounted
  notify: remount mergerfs

- name: Verify mergerfs is mounted
  command: mountpoint -q {{ mergerfs_pool_path }}
  register: mergerfs_mounted
  failed_when: false
  changed_when: false

- name: Mount mergerfs if not mounted
  command: mount {{ mergerfs_pool_path }}
  when: mergerfs_mounted.rc != 0
```

**Step 7**: Configure SnapRAID `tasks/snapraid.yml`
```yaml
---
- name: Create SnapRAID configuration
  template:
    src: snapraid.conf.j2
    dest: /etc/snapraid.conf
    mode: '0644'
    owner: root
    group: root

- name: Create SnapRAID runner script
  copy:
    src: snapraid-runner.sh
    dest: /usr/local/bin/snapraid-runner.sh
    mode: '0755'
    owner: root
    group: root

- name: Create SnapRAID sync systemd service
  copy:
    dest: /etc/systemd/system/snapraid-sync.service
    mode: '0644'
    content: |
      [Unit]
      Description=SnapRAID sync
      After=local-fs.target

      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/snapraid-runner.sh sync
      StandardOutput=journal
      StandardError=journal

- name: Create SnapRAID sync systemd timer
  copy:
    dest: /etc/systemd/system/snapraid-sync.timer
    mode: '0644'
    content: |
      [Unit]
      Description=Run SnapRAID sync

      [Timer]
      OnCalendar={{ snapraid_sync_schedule }}
      Persistent=true

      [Install]
      WantedBy=timers.target
  when: snapraid_sync_enabled
  notify: reload systemd

- name: Create SnapRAID scrub systemd service
  copy:
    dest: /etc/systemd/system/snapraid-scrub.service
    mode: '0644'
    content: |
      [Unit]
      Description=SnapRAID scrub
      After=local-fs.target

      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/snapraid-runner.sh scrub
      StandardOutput=journal
      StandardError=journal

- name: Create SnapRAID scrub systemd timer
  copy:
    dest: /etc/systemd/system/snapraid-scrub.timer
    mode: '0644'
    content: |
      [Unit]
      Description=Run SnapRAID scrub

      [Timer]
      OnCalendar={{ snapraid_scrub_schedule }}
      Persistent=true

      [Install]
      WantedBy=timers.target
  when: snapraid_scrub_enabled
  notify: reload systemd

- name: Enable SnapRAID sync timer
  systemd:
    name: snapraid-sync.timer
    enabled: yes
    state: started
  when: snapraid_sync_enabled

- name: Enable SnapRAID scrub timer
  systemd:
    name: snapraid-scrub.timer
    enabled: yes
    state: started
  when: snapraid_scrub_enabled
```

**Step 8**: Set permissions `tasks/permissions.yml`
```yaml
---
- name: Set ownership on data disks
  file:
    path: "{{ item.mount }}"
    owner: "{{ media_user }}"
    group: "{{ media_user }}"
    mode: '0775'
    state: directory
  loop: "{{ storage_disks }}"

- name: Set ownership on mergerfs pool
  file:
    path: "{{ mergerfs_pool_path }}"
    owner: "{{ media_user }}"
    group: "{{ media_user }}"
    mode: '0775'
    state: directory
```

**Step 9**: Create templates `templates/fstab.j2`
```jinja2
# Storage array disks
{% for disk in storage_disks %}
{{ disk.device }} {{ disk.mount }} {{ disk.fstype }} {{ disk.opts }} 0 0
{% endfor %}

# Parity disk
{{ storage_parity_disk.device }} {{ storage_parity_disk.mount }} {{ storage_parity_disk.fstype }} {{ storage_parity_disk.opts }} 0 0

# MergerFS pool
{{ mergerfs_source_dirs }} {{ mergerfs_pool_path }} fuse.mergerfs {{ mergerfs_opts }} 0 0
```

**Step 10**: Create SnapRAID config template `templates/snapraid.conf.j2`
```jinja2
# SnapRAID configuration file
# Managed by Ansible - DO NOT EDIT MANUALLY

# Parity file
parity {{ snapraid_parity_file }}

# Content files (stored on each data disk for redundancy)
{% for content_file in snapraid_content_files %}
content {{ content_file }}
{% endfor %}

# Data disks
{% for disk in storage_disks %}
data {{ disk.name }} {{ disk.mount }}
{% endfor %}

# Excludes
exclude *.unrecoverable
exclude /tmp/
exclude /lost+found/
exclude downloads/
exclude appdata/
exclude *.!sync

# Hidden files (macOS, Windows cruft)
exclude *.DS_Store
exclude /.Trashes
exclude /.fseventsd
exclude /.Spotlight-V100
exclude /.TemporaryItems
exclude /.DocumentRevisions-V100
exclude /.AppleDB
exclude /.AppleDesktop
exclude /Network Trash Folder
exclude /Temporary Items

# Container/VM data (don't want parity on these)
exclude /lxc/
exclude /images/

# Block size and hash
block_size {{ snapraid_block_size }}
hash {{ snapraid_hash }}
autosave {{ snapraid_autosave }}
```

**Step 11**: Create SnapRAID runner script `files/snapraid-runner.sh`
```bash
#!/bin/bash
# SnapRAID runner script
# Managed by Ansible

set -euo pipefail

SNAPRAID="/usr/local/bin/snapraid"
CONFIG="/etc/snapraid.conf"
LOG_DIR="/var/log/snapraid"
LOG_FILE="${LOG_DIR}/snapraid-$(date +%Y%m%d-%H%M%S).log"

# Create log directory
mkdir -p "${LOG_DIR}"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Check if snapraid is running
if pidof -x snapraid > /dev/null; then
    log "ERROR: SnapRAID is already running"
    exit 1
fi

case "${1:-}" in
    sync)
        log "Starting SnapRAID sync"
        ${SNAPRAID} -c ${CONFIG} sync 2>&1 | tee -a "${LOG_FILE}"
        log "SnapRAID sync completed"
        ;;
    scrub)
        log "Starting SnapRAID scrub ({{ snapraid_scrub_percent }}%)"
        ${SNAPRAID} -c ${CONFIG} scrub -p {{ snapraid_scrub_percent }} 2>&1 | tee -a "${LOG_FILE}"
        log "SnapRAID scrub completed"
        ;;
    status)
        ${SNAPRAID} -c ${CONFIG} status
        ;;
    *)
        echo "Usage: $0 {sync|scrub|status}"
        exit 1
        ;;
esac

# Keep only last 30 days of logs
find "${LOG_DIR}" -name "snapraid-*.log" -mtime +30 -delete

exit 0
```

**Step 12**: Create handlers `handlers/main.yml`
```yaml
---
- name: reload fstab
  command: systemctl daemon-reload

- name: mount disks
  command: mount -a

- name: remount mergerfs
  command: mount -o remount {{ mergerfs_pool_path }}

- name: reload systemd
  systemd:
    daemon_reload: yes
```

---

## Phase 2: Playbook Creation

Create `ansible/playbooks/storage.yml`:
```yaml
---
- name: Configure Proxmox storage (MergerFS + SnapRAID)
  hosts: proxmox_hosts
  become: yes

  pre_tasks:
    - name: Verify required variables
      assert:
        that:
          - storage_disks is defined
          - storage_parity_disk is defined
          - mergerfs_pool_path is defined
        fail_msg: "Required storage variables are not defined"

    - name: Warning about production system
      pause:
        prompt: |
          ⚠️  WARNING: This playbook will configure storage on Proxmox host.
          
          This will:
          - Modify /etc/fstab
          - Install/configure mergerfs
          - Install/configure SnapRAID
          - Mount filesystems
          - Set up automated parity syncs
          
          Existing data will NOT be affected, but configuration will be managed by Ansible.
          
          Type 'yes' to continue
      register: confirm

    - name: Abort if not confirmed
      fail:
        msg: "Storage configuration aborted"
      when: confirm.user_input != 'yes'

  roles:
    - proxmox_storage

  post_tasks:
    - name: Verify mounts
      command: mount | grep -E 'mergerfs|/mnt/disk|/mnt/parity'
      register: mounts
      changed_when: false

    - name: Display mount status
      debug:
        var: mounts.stdout_lines

    - name: Check SnapRAID status
      command: /usr/local/bin/snapraid status
      register: snapraid_status
      changed_when: false

    - name: Display SnapRAID status
      debug:
        var: snapraid_status.stdout_lines

    - name: List enabled timers
      command: systemctl list-timers snapraid-*
      register: timers
      changed_when: false

    - name: Display timer status
      debug:
        var: timers.stdout_lines
```

---

## Phase 3: Testing Strategy

### Step 1: Dry Run
```bash
cd ~/dev/homelab-notes/ansible
ansible-playbook playbooks/storage.yml --check --diff
```

### Step 2: Test Install Only
```bash
ansible-playbook playbooks/storage.yml --tags install --check
```

### Step 3: Backup Current State
```bash
ssh homelab "cp /etc/fstab /etc/fstab.backup-$(date +%Y%m%d)"
```

### Step 4: Apply Configuration
```bash
ansible-playbook playbooks/storage.yml
```

### Step 5: Verify
```bash
# Check mounts
ssh homelab "mount | grep mergerfs"

# Check SnapRAID
ssh homelab "/usr/local/bin/snapraid status"

# Check timers
ssh homelab "systemctl list-timers snapraid-*"

# Test manual sync (optional)
ssh homelab "/usr/local/bin/snapraid-runner.sh sync"
```

---

## Benefits of This Approach

1. **Repeatable**: Can rebuild entire storage config from scratch
2. **Documented**: All config in version-controlled code
3. **Testable**: Dry-run before applying
4. **Idempotent**: Safe to run multiple times
5. **Automated**: SnapRAID runs on schedule automatically
6. **Monitored**: Logs stored in `/var/log/snapraid/`

---

## Next Steps

1. Create the Ansible role structure
2. Test on a VM or non-production system first
3. Back up current /etc/fstab
4. Run playbook with --check first
5. Apply to production
6. Document any customizations needed

---

## Important Notes

### Don't Break What Works!

Your current setup is working - this IaC approach is to:
- **Document** what you have
- **Automate** recreation if needed
- **Add** SnapRAID automation (currently manual)
- **Enable** disaster recovery

### What This Won't Change

- ✅ Data on disks (untouched)
- ✅ Existing parity data (reused)
- ✅ MergerFS pool (reconfigured but same)

### What This Will Add

- ✅ SnapRAID binary (currently missing)
- ✅ SnapRAID config (`/etc/snapraid.conf`)
- ✅ Automated sync schedule (3 AM daily)
- ✅ Automated scrub schedule (weekly)
- ✅ Logging and monitoring

---

**Status**: 📝 Plan complete, ready for implementation  
**Risk**: Low (existing data not affected)  
**Testing**: Should test in VM first, then apply to production
