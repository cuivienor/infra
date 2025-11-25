# Immich Photo Management Deployment - Implementation Plan

> **For Claude:** Use `${SUPERPOWERS_SKILLS_ROOT}/skills/collaboration/executing-plans/SKILL.md` to implement this plan task-by-task.

**Goal:** Deploy Immich photo management system as native services in a privileged LXC container, migrating photos from Google Photos and consolidating old backups.

**Architecture:** Native Immich installation (no Docker) in privileged LXC CT306 running Debian 12. Components run as systemd services (immich-server, immich-ml, PostgreSQL, Redis). NVIDIA GTX 1080 GPU passthrough for ML acceleration.

**Storage Architecture (optimized for performance):**
- SSD (local-lvm): Database, thumbnails, encoded video, ML cache
- HDD (MergerFS): Original photo/video library
- Database: Container root filesystem (SSD, 20GB)
- Thumbnails: Dedicated SSD volume (100GB) at `/var/lib/immich/thumbs`
- Encoded video: Dedicated SSD volume (50GB) at `/var/lib/immich/encoded-video`
- Original library: HDD bind mount from `/mnt/storage/media/photos/library`

Access via Caddy reverse proxy at photos.paniland.com.

**Tech Stack:** Immich (native), Node.js 22, PostgreSQL 18, Redis 8, systemd, Terraform (infrastructure), Ansible (configuration), NVIDIA CUDA, Caddy

---

## Prerequisites

Before starting, verify:
- [ ] Host has `/mnt/storage/media/` available with sufficient space (2TB+ free)
- [ ] NVIDIA GTX 1080 is currently in Jellyfin CT305
- [ ] Caddy proxy is running on CT311
- [ ] Terraform and Ansible are configured with vault password

---

## Task 1: Create Terraform Configuration for Immich Container

**Files:**
- Create: `terraform/immich.tf`
- Modify: `terraform/jellyfin.tf` (remove NVIDIA GPU)

**Step 1: Create immich.tf with container definition**

Create `terraform/immich.tf`:

```hcl
# Immich photo management container
# CT306 - 192.168.1.182

resource "proxmox_virtual_environment_container" "immich" {
  description = "Immich photo management (native installation)"
  node_name   = "homelab"
  vm_id       = 306

  initialization {
    hostname = "immich"

    ip_config {
      ipv4 {
        address = "192.168.1.182/24"
        gateway = "192.168.1.1"
      }
    }

    dns {
      server = "192.168.1.102"  # Primary DNS (Pi4)
    }

    user_account {
      password = var.container_root_password
    }
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  # Privileged container (matches existing homelab pattern)
  unprivileged = false

  cpu {
    cores = 4
  }

  memory {
    dedicated = 16384  # 16GB for ML processing
    swap      = 2048
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20  # 20GB for OS + apps + database + ML cache
  }

  # SSD volume for thumbnails (performance-critical)
  disk {
    datastore_id = "local-lvm"
    size         = 100  # 100GB for thumbnails
  }

  # SSD volume for encoded video (performance-critical)
  disk {
    datastore_id = "local-lvm"
    size         = 50  # 50GB for transcoded videos
  }

  # HDD bind mount for original photo library
  mount_point {
    volume = "/mnt/storage/media/photos/library"
    path   = "/mnt/photos/library"
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  features {
    nesting = true  # Enable for potential Docker future use
  }

  # NVIDIA GTX 1080 GPU passthrough
  # Note: These will be added to /etc/pve/lxc/306.conf after creation
  # lxc.cgroup2.devices.allow: c 195:* rwm
  # lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
  # lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
  # lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
  # lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file

  started = true

  tags = ["photo", "immich", "media"]
}
```

**Step 2: Update jellyfin.tf to remove NVIDIA GPU**

Modify `terraform/jellyfin.tf`, remove all NVIDIA-related lxc entries from the comment block, keeping only Intel Arc:

```hcl
  # Intel Arc A380 GPU passthrough for transcoding
  # lxc.cgroup2.devices.allow: c 226:0 rwm
  # lxc.cgroup2.devices.allow: c 226:128 rwm
  # lxc.mount.entry: /dev/dri/card0 dev/dri/card0 none bind,optional,create=file
  # lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
```

**Step 3: Validate Terraform configuration**

Run:
```bash
cd terraform
terraform fmt
terraform validate
```

Expected: No errors, files formatted

**Step 4: Review Terraform plan**

Run:
```bash
terraform plan
```

Expected output:
- `proxmox_virtual_environment_container.immich` will be created
- `proxmox_virtual_environment_container.jellyfin` will be modified in-place (GPU removal)

**Step 5: Commit Terraform changes**

```bash
git add terraform/immich.tf terraform/jellyfin.tf
git commit -m "feat: add Immich container CT306 and remove NVIDIA GPU from Jellyfin"
```

---

## Task 2: Apply Terraform and Configure GPU Passthrough

**Files:**
- Run: `terraform apply`
- Modify: `/etc/pve/lxc/306.conf` (on Proxmox host)
- Modify: `/etc/pve/lxc/305.conf` (on Proxmox host)

**Step 1: Apply Terraform to create container**

Run:
```bash
cd terraform
terraform apply
```

Type `yes` when prompted.

Expected: CT306 created and started, CT305 modified

**Step 2: Stop containers for GPU configuration**

Run:
```bash
ssh cuiv@homelab "pct stop 305 && pct stop 306"
```

Expected: Both containers stopped

**Step 3: Add NVIDIA GPU passthrough to CT306**

Run on Proxmox host:
```bash
ssh cuiv@homelab 'cat >> /etc/pve/lxc/306.conf << "EOF"

# NVIDIA GTX 1080 GPU passthrough
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
EOF'
```

**Step 4: Verify Jellyfin CT305 config has only Intel Arc**

Run:
```bash
ssh cuiv@homelab "grep -E 'nvidia|dri' /etc/pve/lxc/305.conf"
```

Expected: Only `/dev/dri/card0` and `/dev/dri/renderD128` (Intel Arc), no nvidia devices

**Step 5: Format and mount SSD volumes for thumbnails and encoded video**

Run:
```bash
# Format thumbnails volume (mp1)
ssh root@homelab "pct exec 306 -- mkfs.ext4 /dev/sdb"

# Format encoded-video volume (mp2)
ssh root@homelab "pct exec 306 -- mkfs.ext4 /dev/sdc"

# Create mount points
ssh root@homelab "pct exec 306 -- mkdir -p /var/lib/immich/{thumbs,encoded-video}"

# Add to fstab
ssh root@homelab 'pct exec 306 -- bash -c "echo \"/dev/sdb /var/lib/immich/thumbs ext4 defaults 0 2\" >> /etc/fstab"'
ssh root@homelab 'pct exec 306 -- bash -c "echo \"/dev/sdc /var/lib/immich/encoded-video ext4 defaults 0 2\" >> /etc/fstab"'

# Mount volumes
ssh root@homelab "pct exec 306 -- mount -a"
```

Expected: Both volumes mounted

**Step 6: Verify SSD volumes are mounted**

Run:
```bash
ssh root@homelab "pct exec 306 -- df -h | grep -E 'Filesystem|immich'"
```

Expected output:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb         99G   24K   94G   1% /var/lib/immich/thumbs
/dev/sdc         50G   24K   48G   1% /var/lib/immich/encoded-video
```

**Step 7: Start containers and verify GPU access**

Run:
```bash
ssh cuiv@homelab "pct start 305"
sleep 10
ssh cuiv@homelab "pct exec 306 -- ls -la /dev/nvidia*"
```

Expected: `/dev/nvidia0`, `/dev/nvidiactl`, `/dev/nvidia-uvm`, `/dev/nvidia-modeset` visible in CT306

---

## Task 3: Prepare Storage Directories

**Files:**
- Create: `/mnt/storage/media/photos/library/` (on Proxmox host - HDD)
- Create: `/var/lib/immich/` directories (in container - SSD)

**Step 1: Create library directory on host (HDD)**

Run:
```bash
ssh cuiv@homelab "mkdir -p /mnt/storage/media/photos/library"
```

Expected: Directory created

**Step 2: Set ownership to media user (UID 1000)**

Run:
```bash
ssh cuiv@homelab "chown -R 1000:1000 /mnt/storage/media/photos/library"
ssh cuiv@homelab "chmod 755 /mnt/storage/media/photos/library"
```

Expected: Ownership set

**Step 3: Verify HDD bind mount inside container**

Run:
```bash
ssh cuiv@homelab "pct exec 306 -- ls -la /mnt/photos/library"
```

Expected: Directory visible, owned by UID 1000 (media)

**Step 4: Create Immich directories on SSD volumes**

Run:
```bash
# Set ownership of SSD mount points
ssh root@homelab "pct exec 306 -- chown -R 1000:1000 /var/lib/immich/{thumbs,encoded-video}"

# Create additional directories on container root (SSD)
ssh root@homelab "pct exec 306 -- mkdir -p /var/lib/immich/{upload,profile}"
ssh root@homelab "pct exec 306 -- chown -R 1000:1000 /var/lib/immich/{upload,profile}"
```

Expected: All Immich directories created and owned by media user

---

## Task 4: Add Immich Container to Ansible Inventory

**Files:**
- Modify: `ansible/inventory/hosts.yml`

**Step 1: Add immich_containers group and host**

Add to `ansible/inventory/hosts.yml` after `proxy_containers`:

```yaml
    immich_containers:
      hosts:
        immich:
          ansible_host: 192.168.1.182
          ansible_user: root
          ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
          container_id: 306
```

Also add to `lxc_containers` children list:

```yaml
    lxc_containers:
      children:
        backup_containers:
        samba_containers:
        ripper_containers:
        analyzer_containers:
        transcoder_containers:
        jellyfin_containers:
        dns_containers:
        proxy_containers:
        immich_containers:  # Add this line
```

**Step 2: Test Ansible connectivity**

Run:
```bash
cd ansible
ansible immich_containers -m ping
```

Expected: `immich | SUCCESS => {"ping": "pong"}`

**Step 3: Commit inventory changes**

```bash
git add ansible/inventory/hosts.yml
git commit -m "feat: add Immich container to Ansible inventory"
```

---

## Task 5: Create Ansible Role Structure for Immich

**Files:**
- Create: `ansible/roles/immich/` (directory structure)
- Create: `ansible/roles/immich/defaults/main.yml`
- Create: `ansible/roles/immich/meta/main.yml`
- Create: `ansible/roles/immich/handlers/main.yml`

**Step 1: Create role directory structure**

Run:
```bash
mkdir -p ansible/roles/immich/{tasks,templates,files,handlers,defaults,meta}
```

**Step 2: Create defaults/main.yml**

Create `ansible/roles/immich/defaults/main.yml`:

```yaml
---
# Immich role default variables

# Immich version (git tag or commit hash)
immich_version: "v1.119.1"  # Update to latest stable

# Installation paths
immich_install_dir: "/opt/immich"
immich_data_dir: "/var/lib/immich"

# Storage locations (optimized for performance)
immich_upload_location: "/var/lib/immich/upload"          # SSD - active uploads
immich_library_location: "/mnt/photos/library"            # HDD - original library
immich_thumbs_location: "/var/lib/immich/thumbs"          # SSD - thumbnails
immich_encoded_video_location: "/var/lib/immich/encoded-video"  # SSD - transcoded video
immich_profile_location: "/var/lib/immich/profile"        # SSD - user profiles

# System user
immich_user: "media"
immich_group: "media"
immich_uid: 1000
immich_gid: 1000

# Node.js version
nodejs_major_version: "22"

# PostgreSQL configuration
postgresql_version: "18"
immich_db_name: "immich"
immich_db_user: "immich"
immich_db_password: "{{ vault_immich_db_password }}"  # From vault

# Redis configuration
redis_version: "7:8.2.2-1"  # From Redis APT repo

# NVIDIA CUDA (for GPU acceleration)
cuda_enabled: true
nvidia_driver_version: "535"  # Match host version

# Service ports
immich_server_port: 2283
immich_ml_port: 3003
```

**Step 3: Create meta/main.yml**

Create `ansible/roles/immich/meta/main.yml`:

```yaml
---
dependencies:
  - role: common
```

**Step 4: Create handlers/main.yml**

Create `ansible/roles/immich/handlers/main.yml`:

```yaml
---
- name: Restart immich-server
  ansible.builtin.systemd:
    name: immich-server
    state: restarted
    daemon_reload: true

- name: Restart immich-microservices
  ansible.builtin.systemd:
    name: immich-microservices
    state: restarted
    daemon_reload: true

- name: Restart immich-machine-learning
  ansible.builtin.systemd:
    name: immich-machine-learning
    state: restarted
    daemon_reload: true

- name: Restart postgresql
  ansible.builtin.systemd:
    name: postgresql
    state: restarted

- name: Restart redis
  ansible.builtin.systemd:
    name: redis-server
    state: restarted
```

**Step 5: Commit role structure**

```bash
git add ansible/roles/immich/
git commit -m "feat: create Immich Ansible role structure"
```

---

## Task 6: Create System Dependencies Installation Task

**Files:**
- Create: `ansible/roles/immich/tasks/main.yml`
- Create: `ansible/roles/immich/tasks/dependencies.yml`

**Step 1: Create main.yml orchestration**

Create `ansible/roles/immich/tasks/main.yml`:

```yaml
---
- name: Include dependency installation
  ansible.builtin.include_tasks: dependencies.yml
  tags: ['dependencies']

- name: Include PostgreSQL setup
  ansible.builtin.include_tasks: database.yml
  tags: ['database']

- name: Include Redis setup
  ansible.builtin.include_tasks: redis.yml
  tags: ['redis']

- name: Include NVIDIA GPU setup
  ansible.builtin.include_tasks: gpu.yml
  tags: ['gpu']
  when: cuda_enabled | bool

- name: Include Immich installation
  ansible.builtin.include_tasks: install.yml
  tags: ['install']

- name: Include systemd service setup
  ansible.builtin.include_tasks: systemd.yml
  tags: ['systemd']
```

**Step 2: Create dependencies.yml**

Create `ansible/roles/immich/tasks/dependencies.yml`:

```yaml
---
- name: Update apt cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600

- name: Install base build tools
  ansible.builtin.apt:
    name:
      - build-essential
      - git
      - curl
      - wget
      - ca-certificates
      - gnupg
      - lsb-release
      - unzip
      - jq
      - python3
      - python3-pip
      - python3-venv
    state: present

- name: Add NodeSource GPG key
  ansible.builtin.get_url:
    url: "https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
    dest: /etc/apt/keyrings/nodesource.asc
    mode: '0644'

- name: Add NodeSource repository
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/nodesource.asc] https://deb.nodesource.com/node_{{ nodejs_major_version }}.x nodistro main"
    state: present
    filename: nodesource

- name: Install Node.js
  ansible.builtin.apt:
    name: nodejs
    state: present
    update_cache: true

- name: Verify Node.js installation
  ansible.builtin.command: node --version
  register: node_version
  changed_when: false

- name: Display Node.js version
  ansible.builtin.debug:
    msg: "Installed Node.js {{ node_version.stdout }}"

- name: Install FFmpeg from Jellyfin repository
  block:
    - name: Add Jellyfin GPG key
      ansible.builtin.get_url:
        url: "https://repo.jellyfin.org/debian/jellyfin_team.gpg.key"
        dest: /etc/apt/keyrings/jellyfin.asc
        mode: '0644'

    - name: Add Jellyfin repository
      ansible.builtin.apt_repository:
        repo: "deb [signed-by=/etc/apt/keyrings/jellyfin.asc arch=amd64] https://repo.jellyfin.org/debian bookworm main"
        state: present
        filename: jellyfin

    - name: Install FFmpeg
      ansible.builtin.apt:
        name: jellyfin-ffmpeg6
        state: present
        update_cache: true

- name: Create media user if not exists
  ansible.builtin.user:
    name: "{{ immich_user }}"
    uid: "{{ immich_uid }}"
    group: "{{ immich_group }}"
    shell: /bin/bash
    create_home: true
    state: present

- name: Create Immich directories
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ immich_user }}"
    group: "{{ immich_group }}"
    mode: '0755'
  loop:
    - "{{ immich_install_dir }}"
    - "{{ immich_data_dir }}"
    - "{{ immich_upload_location }}"
```

**Step 3: Verify task syntax**

Run:
```bash
cd ansible
ansible-playbook --syntax-check -i inventory/hosts.yml roles/immich/tasks/dependencies.yml
```

Expected: No syntax errors

**Step 4: Commit dependencies task**

```bash
git add ansible/roles/immich/tasks/
git commit -m "feat: add Immich dependencies installation tasks"
```

---

## Task 7: Create PostgreSQL Database Setup Task

**Files:**
- Create: `ansible/roles/immich/tasks/database.yml`

**Step 1: Create database.yml**

Create `ansible/roles/immich/tasks/database.yml`:

```yaml
---
- name: Add PostgreSQL APT repository key
  ansible.builtin.get_url:
    url: "https://www.postgresql.org/media/keys/ACCC4CF8.asc"
    dest: /etc/apt/keyrings/postgresql.asc
    mode: '0644'

- name: Add PostgreSQL APT repository
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main"
    state: present
    filename: pgdg

- name: Install PostgreSQL
  ansible.builtin.apt:
    name:
      - "postgresql-{{ postgresql_version }}"
      - "postgresql-contrib-{{ postgresql_version }}"
      - python3-psycopg2
    state: present
    update_cache: true

- name: Ensure PostgreSQL is started and enabled
  ansible.builtin.systemd:
    name: postgresql
    state: started
    enabled: true

- name: Create Immich database
  become: true
  become_user: postgres
  community.postgresql.postgresql_db:
    name: "{{ immich_db_name }}"
    encoding: UTF8
    lc_collate: en_US.UTF-8
    lc_ctype: en_US.UTF-8
    template: template0
    state: present

- name: Create Immich database user
  become: true
  become_user: postgres
  community.postgresql.postgresql_user:
    name: "{{ immich_db_user }}"
    password: "{{ immich_db_password }}"
    db: "{{ immich_db_name }}"
    priv: ALL
    state: present

- name: Install pgvector extension dependencies
  ansible.builtin.apt:
    name:
      - "postgresql-server-dev-{{ postgresql_version }}"
      - libpq-dev
    state: present

- name: Clone pgvector repository
  ansible.builtin.git:
    repo: https://github.com/pgvector/pgvector.git
    dest: /tmp/pgvector
    version: v0.8.0
    force: true

- name: Build and install pgvector
  ansible.builtin.shell: |
    cd /tmp/pgvector
    make clean
    make OPTFLAGS=""
    make install
  args:
    creates: "/usr/lib/postgresql/{{ postgresql_version }}/lib/vector.so"

- name: Enable pgvector extension in database
  become: true
  become_user: postgres
  community.postgresql.postgresql_ext:
    name: vector
    db: "{{ immich_db_name }}"
    state: present

- name: Clone pgvecto.rs repository
  ansible.builtin.git:
    repo: https://github.com/tensorchord/pgvecto.rs.git
    dest: /tmp/pgvecto-rs
    version: v0.3.0
    force: true

- name: Install Rust (required for pgvecto.rs)
  ansible.builtin.shell: |
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  args:
    creates: /root/.cargo/bin/rustc
  environment:
    CARGO_HOME: /root/.cargo

- name: Build and install pgvecto.rs
  ansible.builtin.shell: |
    source /root/.cargo/env
    cd /tmp/pgvecto-rs
    cargo pgrx init --pg{{ postgresql_version }}=/usr/lib/postgresql/{{ postgresql_version }}/bin/pg_config
    cargo pgrx install --release
  args:
    creates: "/usr/lib/postgresql/{{ postgresql_version }}/lib/vectors.so"
  environment:
    CARGO_HOME: /root/.cargo
    PATH: "/root/.cargo/bin:{{ ansible_env.PATH }}"

- name: Configure PostgreSQL for pgvecto.rs
  ansible.builtin.lineinfile:
    path: "/etc/postgresql/{{ postgresql_version }}/main/postgresql.conf"
    regexp: "^shared_preload_libraries"
    line: "shared_preload_libraries = 'vectors.so'"
    state: present
  notify: Restart postgresql

- name: Optimize PostgreSQL settings for SSD
  ansible.builtin.blockinfile:
    path: "/etc/postgresql/{{ postgresql_version }}/main/postgresql.conf"
    block: |
      # Immich optimizations
      shared_buffers = 512MB
      effective_cache_size = 4GB
      maintenance_work_mem = 256MB
      wal_compression = on
      max_wal_size = 2GB
    marker: "# {mark} IMMICH OPTIMIZATIONS"
  notify: Restart postgresql

- name: Flush handlers to restart PostgreSQL
  ansible.builtin.meta: flush_handlers

- name: Enable vectors extension in database
  become: true
  become_user: postgres
  community.postgresql.postgresql_query:
    db: "{{ immich_db_name }}"
    query: "CREATE EXTENSION IF NOT EXISTS vectors;"
```

**Step 2: Verify task syntax**

Run:
```bash
ansible-playbook --syntax-check -i inventory/hosts.yml roles/immich/tasks/database.yml
```

Expected: No syntax errors

**Step 3: Commit database task**

```bash
git add ansible/roles/immich/tasks/database.yml
git commit -m "feat: add PostgreSQL database setup for Immich"
```

---

## Task 8: Create Redis Setup Task

**Files:**
- Create: `ansible/roles/immich/tasks/redis.yml`

**Step 1: Create redis.yml**

Create `ansible/roles/immich/tasks/redis.yml`:

```yaml
---
- name: Add Redis GPG key
  ansible.builtin.get_url:
    url: "https://packages.redis.io/gpg"
    dest: /etc/apt/keyrings/redis.asc
    mode: '0644'

- name: Add Redis repository
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/etc/apt/keyrings/redis.asc] https://packages.redis.io/deb bookworm main"
    state: present
    filename: redis

- name: Install Redis
  ansible.builtin.apt:
    name: redis
    state: present
    update_cache: true

- name: Ensure Redis is started and enabled
  ansible.builtin.systemd:
    name: redis-server
    state: started
    enabled: true

- name: Configure Redis for Immich
  ansible.builtin.lineinfile:
    path: /etc/redis/redis.conf
    regexp: "{{ item.regexp }}"
    line: "{{ item.line }}"
    state: present
  loop:
    - { regexp: '^bind ', line: 'bind 127.0.0.1 ::1' }
    - { regexp: '^protected-mode ', line: 'protected-mode yes' }
    - { regexp: '^maxmemory ', line: 'maxmemory 256mb' }
    - { regexp: '^maxmemory-policy ', line: 'maxmemory-policy allkeys-lru' }
  notify: Restart redis
```

**Step 2: Commit Redis task**

```bash
git add ansible/roles/immich/tasks/redis.yml
git commit -m "feat: add Redis setup for Immich"
```

---

## Task 9: Create NVIDIA GPU Setup Task

**Files:**
- Create: `ansible/roles/immich/tasks/gpu.yml`

**Step 1: Create gpu.yml**

Create `ansible/roles/immich/tasks/gpu.yml`:

```yaml
---
- name: Check if NVIDIA devices exist
  ansible.builtin.stat:
    path: /dev/nvidia0
  register: nvidia_device

- name: Install NVIDIA drivers
  when: nvidia_device.stat.exists
  block:
    - name: Add NVIDIA CUDA repository key
      ansible.builtin.get_url:
        url: "https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/3bf863cc.pub"
        dest: /etc/apt/keyrings/nvidia-cuda.asc
        mode: '0644'

    - name: Add NVIDIA CUDA repository
      ansible.builtin.apt_repository:
        repo: "deb [signed-by=/etc/apt/keyrings/nvidia-cuda.asc] https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/ /"
        state: present
        filename: nvidia-cuda

    - name: Install NVIDIA driver packages
      ansible.builtin.apt:
        name:
          - "nvidia-driver-{{ nvidia_driver_version }}"
          - "nvidia-kernel-dkms-{{ nvidia_driver_version }}"
          - "libnvidia-encode{{ nvidia_driver_version }}"
          - "libnvcuvid1"
          - cuda-toolkit-12-8
        state: present
        update_cache: true

    - name: Verify NVIDIA driver installation
      ansible.builtin.command: nvidia-smi
      register: nvidia_smi_output
      changed_when: false

    - name: Display nvidia-smi output
      ansible.builtin.debug:
        msg: "{{ nvidia_smi_output.stdout_lines }}"

- name: Skip GPU setup if no NVIDIA device found
  when: not nvidia_device.stat.exists
  ansible.builtin.debug:
    msg: "No NVIDIA GPU detected, skipping GPU setup"
```

**Step 2: Commit GPU task**

```bash
git add ansible/roles/immich/tasks/gpu.yml
git commit -m "feat: add NVIDIA GPU setup for Immich"
```

---

## Task 10: Create Immich Installation Script

**Files:**
- Create: `ansible/roles/immich/files/install-immich.sh`
- Create: `ansible/roles/immich/tasks/install.yml`

**Step 1: Create install-immich.sh**

Create `ansible/roles/immich/files/install-immich.sh`:

```bash
#!/bin/bash
# Immich native installation script
# Based on loeeeee/immich-in-lxc

set -e

IMMICH_VERSION="${IMMICH_VERSION:-v1.119.1}"
INSTALL_DIR="${INSTALL_DIR:-/opt/immich}"
DATA_DIR="${DATA_DIR:-/var/lib/immich}"

echo "Installing Immich ${IMMICH_VERSION}..."

# Clone Immich repository
cd /tmp
rm -rf immich-app
git clone --depth 1 --branch "${IMMICH_VERSION}" https://github.com/immich-app/immich.git immich-app
cd immich-app

# Install server dependencies
cd server
npm ci
npm run build
npm prune --omit=dev --omit=optional

# Install machine learning dependencies
cd ../machine-learning
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# Copy built application to install directory
cd ..
mkdir -p "${INSTALL_DIR}"
cp -r server "${INSTALL_DIR}/"
cp -r machine-learning "${INSTALL_DIR}/"

# Data directories are already created and mounted by Terraform/Ansible
# Just set permissions on the install directory
chown -R media:media "${INSTALL_DIR}"

echo "Immich ${IMMICH_VERSION} installed successfully to ${INSTALL_DIR}"
```

**Step 2: Create install.yml**

Create `ansible/roles/immich/tasks/install.yml`:

```yaml
---
- name: Copy Immich installation script
  ansible.builtin.copy:
    src: install-immich.sh
    dest: /tmp/install-immich.sh
    mode: '0755'

- name: Run Immich installation script
  ansible.builtin.command:
    cmd: /tmp/install-immich.sh
  environment:
    IMMICH_VERSION: "{{ immich_version }}"
    INSTALL_DIR: "{{ immich_install_dir }}"
    DATA_DIR: "{{ immich_data_dir }}"
  args:
    creates: "{{ immich_install_dir }}/server/dist/main.js"

- name: Create Immich environment file
  ansible.builtin.template:
    src: immich.env.j2
    dest: "{{ immich_install_dir }}/.env"
    owner: "{{ immich_user }}"
    group: "{{ immich_group }}"
    mode: '0600'
  notify:
    - Restart immich-server
    - Restart immich-microservices
    - Restart immich-machine-learning
```

**Step 3: Commit installation files**

```bash
git add ansible/roles/immich/files/install-immich.sh ansible/roles/immich/tasks/install.yml
git commit -m "feat: add Immich native installation script"
```

---

## Task 11: Create Environment Configuration Template

**Files:**
- Create: `ansible/roles/immich/templates/immich.env.j2`

**Step 1: Create immich.env.j2**

Create `ansible/roles/immich/templates/immich.env.j2`:

```bash
# Immich environment configuration
# Generated by Ansible - do not edit manually

# Database
DB_HOSTNAME=localhost
DB_PORT=5432
DB_USERNAME={{ immich_db_user }}
DB_PASSWORD={{ immich_db_password }}
DB_DATABASE_NAME={{ immich_db_name }}

# Redis
REDIS_HOSTNAME=localhost
REDIS_PORT=6379
REDIS_DBINDEX=0

# Storage locations (performance-optimized)
UPLOAD_LOCATION={{ immich_upload_location }}
LIBRARY_LOCATION={{ immich_library_location }}
THUMB_LOCATION={{ immich_thumbs_location }}
ENCODED_VIDEO_LOCATION={{ immich_encoded_video_location }}
PROFILE_LOCATION={{ immich_profile_location }}

# Machine Learning
MACHINE_LEARNING_URL=http://localhost:{{ immich_ml_port }}

# Server
IMMICH_PORT={{ immich_server_port }}
IMMICH_ENV=production

# Log level
LOG_LEVEL=log

# Public login page message (optional)
PUBLIC_LOGIN_PAGE_MESSAGE=

# Disable telemetry
IMMICH_TELEMETRY_INCLUDE=none

# Node environment
NODE_ENV=production
```

**Step 2: Commit environment template**

```bash
git add ansible/roles/immich/templates/immich.env.j2
git commit -m "feat: add Immich environment configuration template"
```

---

## Task 12: Create Systemd Service Templates

**Files:**
- Create: `ansible/roles/immich/templates/immich-server.service.j2`
- Create: `ansible/roles/immich/templates/immich-microservices.service.j2`
- Create: `ansible/roles/immich/templates/immich-machine-learning.service.j2`
- Create: `ansible/roles/immich/tasks/systemd.yml`

**Step 1: Create immich-server.service.j2**

Create `ansible/roles/immich/templates/immich-server.service.j2`:

```ini
[Unit]
Description=Immich Server
After=network.target postgresql.service redis-server.service
Wants=postgresql.service redis-server.service

[Service]
Type=simple
User={{ immich_user }}
Group={{ immich_group }}
WorkingDirectory={{ immich_install_dir }}/server
EnvironmentFile={{ immich_install_dir }}/.env
ExecStart=/usr/bin/node {{ immich_install_dir }}/server/dist/main.js
Restart=always
RestartSec=10

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths={{ immich_data_dir }} {{ immich_upload_location }}

[Install]
WantedBy=multi-user.target
```

**Step 2: Create immich-microservices.service.j2**

Create `ansible/roles/immich/templates/immich-microservices.service.j2`:

```ini
[Unit]
Description=Immich Microservices
After=network.target postgresql.service redis-server.service immich-server.service
Wants=postgresql.service redis-server.service immich-server.service

[Service]
Type=simple
User={{ immich_user }}
Group={{ immich_group }}
WorkingDirectory={{ immich_install_dir }}/server
EnvironmentFile={{ immich_install_dir }}/.env
ExecStart=/usr/bin/node {{ immich_install_dir }}/server/dist/workers/microservices.js
Restart=always
RestartSec=10

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths={{ immich_data_dir }} {{ immich_upload_location }}

[Install]
WantedBy=multi-user.target
```

**Step 3: Create immich-machine-learning.service.j2**

Create `ansible/roles/immich/templates/immich-machine-learning.service.j2`:

```ini
[Unit]
Description=Immich Machine Learning
After=network.target
Wants=network.target

[Service]
Type=simple
User={{ immich_user }}
Group={{ immich_group }}
WorkingDirectory={{ immich_install_dir }}/machine-learning
EnvironmentFile={{ immich_install_dir }}/.env
ExecStart={{ immich_install_dir }}/machine-learning/venv/bin/python {{ immich_install_dir }}/machine-learning/src/main.py
Restart=always
RestartSec=10

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths={{ immich_data_dir }}

[Install]
WantedBy=multi-user.target
```

**Step 4: Create systemd.yml**

Create `ansible/roles/immich/tasks/systemd.yml`:

```yaml
---
- name: Install Immich systemd service files
  ansible.builtin.template:
    src: "{{ item }}.j2"
    dest: "/etc/systemd/system/{{ item }}"
    mode: '0644'
  loop:
    - immich-server.service
    - immich-microservices.service
    - immich-machine-learning.service
  notify:
    - Restart immich-server
    - Restart immich-microservices
    - Restart immich-machine-learning

- name: Reload systemd daemon
  ansible.builtin.systemd:
    daemon_reload: true

- name: Enable and start Immich services
  ansible.builtin.systemd:
    name: "{{ item }}"
    enabled: true
    state: started
  loop:
    - immich-server
    - immich-microservices
    - immich-machine-learning
```

**Step 5: Commit systemd templates and task**

```bash
git add ansible/roles/immich/templates/*.service.j2 ansible/roles/immich/tasks/systemd.yml
git commit -m "feat: add Immich systemd service templates"
```

---

## Task 13: Create Immich Playbook

**Files:**
- Create: `ansible/playbooks/immich.yml`

**Step 1: Create immich.yml playbook**

Create `ansible/playbooks/immich.yml`:

```yaml
---
- name: Deploy Immich photo management
  hosts: immich_containers
  become: true

  pre_tasks:
    - name: Wait for container to be ready
      ansible.builtin.wait_for_connection:
        timeout: 60

    - name: Gather facts
      ansible.builtin.setup:

  roles:
    - role: common
      tags: ['common']
    - role: immich
      tags: ['immich']

  post_tasks:
    - name: Verify Immich services are running
      ansible.builtin.systemd:
        name: "{{ item }}"
        state: started
      loop:
        - immich-server
        - immich-microservices
        - immich-machine-learning
      register: service_status

    - name: Display Immich service status
      ansible.builtin.debug:
        msg:
          - "========================================="
          - "✅ Immich deployment complete!"
          - "========================================="
          - "Container: {{ ansible_facts['hostname'] }}"
          - "IP Address: {{ ansible_facts['default_ipv4'].address }}"
          - "Immich Server: http://{{ ansible_facts['default_ipv4'].address }}:2283"
          - "Services: immich-server, immich-microservices, immich-machine-learning"
          - "========================================="
          - "Next steps:"
          - "1. Access web UI at http://{{ ansible_facts['default_ipv4'].address }}:2283"
          - "2. Create admin account"
          - "3. Configure Caddy reverse proxy for HTTPS access"
          - "========================================="
```

**Step 2: Commit playbook**

```bash
git add ansible/playbooks/immich.yml
git commit -m "feat: create Immich deployment playbook"
```

---

## Task 14: Add Immich Database Password to Vault

**Files:**
- Modify: `ansible/vars/secrets.yml` (encrypted)

**Step 1: Generate secure database password**

Run:
```bash
openssl rand -base64 32
```

Expected: Random password string (save for next step)

**Step 2: Edit encrypted vault file**

Run:
```bash
cd ansible
ansible-vault edit vars/secrets.yml --vault-password-file ../.vault_pass
```

Add:
```yaml
vault_immich_db_password: "<password-from-step-1>"
```

Save and exit.

**Step 3: Verify vault file is still encrypted**

Run:
```bash
file ansible/vars/secrets.yml
```

Expected: `ansible/vars/secrets.yml: data` (encrypted, not plaintext)

**Step 4: Commit vault changes**

```bash
git add ansible/vars/secrets.yml
git commit -m "feat: add Immich database password to vault"
```

---

## Task 15: Deploy Immich via Ansible

**Files:**
- Run: `ansible-playbook ansible/playbooks/immich.yml`

**Step 1: Syntax check playbook**

Run:
```bash
cd ansible
ansible-playbook playbooks/immich.yml --syntax-check
```

Expected: No syntax errors

**Step 2: Run playbook in check mode (dry-run)**

Run:
```bash
ansible-playbook playbooks/immich.yml --vault-password-file ../.vault_pass --check
```

Expected: Shows what would be changed, no errors

**Step 3: Deploy Immich**

Run:
```bash
ansible-playbook playbooks/immich.yml --vault-password-file ../.vault_pass
```

Expected: All tasks complete successfully, services started

**Step 4: Verify services are running**

Run:
```bash
ssh root@immich.home.arpa "systemctl status immich-server immich-microservices immich-machine-learning"
```

Expected: All three services active (running)

**Step 5: Verify web UI is accessible**

Run:
```bash
curl -I http://192.168.1.182:2283/api/server-info/ping
```

Expected: HTTP 200 OK response

---

## Task 16: Update Caddy Configuration for Reverse Proxy

**Files:**
- Modify: `ansible/roles/caddy/templates/Caddyfile.j2`

**Step 1: Add photos.paniland.com to Caddyfile**

Add to `ansible/roles/caddy/templates/Caddyfile.j2`:

```
photos.paniland.com {
  reverse_proxy immich:2283

  # Handle large photo uploads
  request_body {
    max_size 2GB
  }

  # WebSocket support for live updates
  @websocket {
    header Connection *Upgrade*
    header Upgrade websocket
  }
  reverse_proxy @websocket immich:2283
}
```

**Step 2: Re-run Caddy playbook**

Run:
```bash
ansible-playbook playbooks/proxy.yml --vault-password-file ../.vault_pass --tags caddy
```

Expected: Caddy configuration reloaded

**Step 3: Verify HTTPS access**

Run:
```bash
curl -I https://photos.paniland.com/api/server-info/ping
```

Expected: HTTP 200 OK with valid certificate

**Step 4: Commit Caddy configuration changes**

```bash
git add ansible/roles/caddy/templates/Caddyfile.j2
git commit -m "feat: add photos.paniland.com reverse proxy to Caddy"
```

---

## Task 17: Initial Immich Configuration

**Files:**
- N/A (web UI configuration)

**Step 1: Access Immich web UI**

Open browser: `https://photos.paniland.com`

Expected: Immich welcome screen

**Step 2: Create admin account**

- Email: <your-email>
- Password: <secure-password>
- Name: <your-name>

Click "Sign Up"

Expected: Logged in as admin

**Step 3: Create partner account**

Navigate to: Administration → Users → Create User

- Email: <partner-email>
- Password: <partner-password>
- Name: <partner-name>

Click "Create"

Expected: Partner user created

**Step 4: Generate API keys for both users**

For your account:
- Account Settings → API Keys → New API Key
- Name: "Migration Import"
- Copy and save API key securely

Repeat for partner account (login as partner)

**Step 5: Configure storage template**

Administration → Settings → Storage Template

Set to: `{{y}}/{{MM}}/{{dd}}/{{filename}}`

Click "Save"

Expected: Storage template updated

**Step 6: Enable partner sharing**

For your account:
- Account Settings → Partner Sharing
- Add partner by email
- Toggle "Show in timeline"

Repeat for partner account

Expected: Partner sharing enabled for both

---

## Task 18: Update Documentation

**Files:**
- Modify: `docs/reference/current-state.md`
- Modify: `docs/reference/ip-allocation-strategy.md`
- Create: `docs/guides/immich-management.md`

**Step 1: Update current-state.md**

Add to container inventory table in `docs/reference/current-state.md`:

```markdown
| 306 | immich | .182 | Photo management (Immich) |
```

Update services section:
```markdown
### Photo Management (Immich)
- **Host**: CT306 (192.168.1.182)
- **Web UI**: https://photos.paniland.com
- **Storage**: /mnt/storage/media/photos/
- **GPU**: NVIDIA GTX 1080 (ML acceleration)
- **Services**: immich-server, immich-microservices, immich-machine-learning
```

**Step 2: Update ip-allocation-strategy.md**

Change `.182` status:
```markdown
| .182 | Immich | CT306 | ✅ Active | Photo management |
```

**Step 3: Create immich-management.md**

Create `docs/guides/immich-management.md`:

```markdown
# Immich Management Guide

## Service Management

### Check Status
\`\`\`bash
ssh root@immich.home.arpa "systemctl status immich-server"
ssh root@immich.home.arpa "systemctl status immich-microservices"
ssh root@immich.home.arpa "systemctl status immich-machine-learning"
\`\`\`

### Restart Services
\`\`\`bash
ssh root@immich.home.arpa "systemctl restart immich-server"
ssh root@immich.home.arpa "systemctl restart immich-microservices"
ssh root@immich.home.arpa "systemctl restart immich-machine-learning"
\`\`\`

### View Logs
\`\`\`bash
ssh root@immich.home.arpa "journalctl -u immich-server -f"
ssh root@immich.home.arpa "journalctl -u immich-microservices -f"
ssh root@immich.home.arpa "journalctl -u immich-machine-learning -f"
\`\`\`

## Database Management

### Backup Database
\`\`\`bash
ssh root@immich.home.arpa "sudo -u postgres pg_dump immich | gzip > /mnt/photos/backup/immich-db-\$(date +%Y%m%d).sql.gz"
\`\`\`

### Restore Database
\`\`\`bash
ssh root@immich.home.arpa "gunzip < /mnt/photos/backup/immich-db-YYYYMMDD.sql.gz | sudo -u postgres psql immich"
\`\`\`

### Check Database Size
\`\`\`bash
ssh root@immich.home.arpa "sudo -u postgres psql -d immich -c \"SELECT pg_size_pretty(pg_database_size('immich'));\""
\`\`\`

## GPU Monitoring

### Check GPU Status
\`\`\`bash
ssh root@immich.home.arpa "nvidia-smi"
\`\`\`

### Monitor GPU Usage
\`\`\`bash
ssh root@immich.home.arpa "watch -n 1 nvidia-smi"
\`\`\`

## Storage Management

### Check Photo Storage Usage
\`\`\`bash
ssh root@immich.home.arpa "du -sh /mnt/photos/*"
\`\`\`

### Check Available Space
\`\`\`bash
ssh root@immich.home.arpa "df -h /mnt/photos"
\`\`\`

## Updates

### Update Immich
\`\`\`bash
# Edit version in ansible/roles/immich/defaults/main.yml
# Then re-run playbook
ansible-playbook ansible/playbooks/immich.yml --vault-password-file .vault_pass --tags install,systemd
\`\`\`

## Troubleshooting

### Service Won't Start
Check logs:
\`\`\`bash
journalctl -u immich-server -n 100
\`\`\`

Common issues:
- Database not running: `systemctl start postgresql`
- Redis not running: `systemctl start redis-server`
- Permissions: Check /mnt/photos ownership (should be media:media)

### Web UI Not Accessible
- Check service: `systemctl status immich-server`
- Check port: `netstat -tlnp | grep 2283`
- Check Caddy: `systemctl status caddy`

### ML Processing Slow
- Check GPU: `nvidia-smi`
- Check CUDA: `nvcc --version`
- Increase RAM if needed in terraform/immich.tf

## API Access

### Using API Keys
\`\`\`bash
curl -H "x-api-key: YOUR_API_KEY" https://photos.paniland.com/api/assets
\`\`\`

### Install immich-go for CLI Operations
\`\`\`bash
wget https://github.com/simulot/immich-go/releases/latest/download/immich-go_Linux_x86_64.tar.gz
tar xzf immich-go_Linux_x86_64.tar.gz
sudo mv immich-go /usr/local/bin/
\`\`\`
```

**Step 4: Commit documentation updates**

```bash
git add docs/reference/current-state.md docs/reference/ip-allocation-strategy.md docs/guides/immich-management.md
git commit -m "docs: update infrastructure docs for Immich deployment"
```

---

## Task 19: Configure Backup Integration

**Files:**
- Modify: `ansible/roles/restic_backup/tasks/main.yml` (or create new backup task)

**Step 1: Add Immich database backup cron job**

Add to backup container's crontab or create systemd timer:

```yaml
- name: Create Immich database backup script
  ansible.builtin.copy:
    dest: /usr/local/bin/backup-immich-db.sh
    mode: '0755'
    content: |
      #!/bin/bash
      set -e
      BACKUP_DIR="/mnt/storage/backups/immich"
      mkdir -p "$BACKUP_DIR"
      ssh root@immich.home.arpa "sudo -u postgres pg_dump immich | gzip" > "$BACKUP_DIR/immich-db-$(date +%Y%m%d-%H%M%S).sql.gz"
      # Keep only last 7 days
      find "$BACKUP_DIR" -name "immich-db-*.sql.gz" -mtime +7 -delete

- name: Schedule Immich database backup
  ansible.builtin.cron:
    name: "Backup Immich database"
    hour: "2"
    minute: "0"
    job: "/usr/local/bin/backup-immich-db.sh"
    user: root
```

**Step 2: Add photos to Restic backup paths**

Ensure `/mnt/storage/media/photos/` is included in Restic backup configuration.

**Step 3: Re-run backup playbook**

```bash
ansible-playbook ansible/playbooks/backup.yml --vault-password-file .vault_pass
```

**Step 4: Verify backup script works**

```bash
ssh root@backup.home.arpa "/usr/local/bin/backup-immich-db.sh"
ssh root@backup.home.arpa "ls -lh /mnt/storage/backups/immich/"
```

Expected: Database backup file created

**Step 5: Commit backup configuration**

```bash
git add ansible/roles/restic_backup/
git commit -m "feat: add Immich database backup to automated backups"
```

---

## Task 20: Photo Migration - Google Takeout Export

**Files:**
- N/A (manual process, documented in existing plan)

**Step 1: Request Google Takeout (both partners)**

Follow instructions in `docs/plans/photo-management-migration.md` Phase 1:

1. Go to takeout.google.com
2. Select only "Google Photos"
3. Export once, .zip format, 50GB files
4. Note start date

**Step 2: Save photos from shared albums**

While waiting for export:
- Go to Google Photos → Sharing
- Open shared albums you don't own
- Select important photos → "Save to your account"

**Step 3: Document export details**

Create tracking file:
```bash
cat > ~/immich-migration-log.md << 'EOF'
# Immich Migration Log

## Google Takeout Export

**Start Date**: YYYY-MM-DD
**Partners**:
- User 1: Export requested, estimated completion:
- User 2: Export requested, estimated completion:

**Shared Albums Saved**:
- [ ] Album 1 (XX photos)
- [ ] Album 2 (XX photos)

**Library Sizes**:
- User 1 Google Photos: XX GB
- User 2 Google Photos: XX GB
- Estimated total: XX GB

## Cutover Plan

**Cutover Date**: TBD (when Takeout ready)
EOF
```

Expected: Takeout exports will arrive in 1-7 days via email

---

## Task 21: Install immich-go CLI Tool

**Files:**
- N/A (binary installation)

**Step 1: Download immich-go**

Run on your workstation or a container with access to Immich:

```bash
cd /tmp
wget https://github.com/simulot/immich-go/releases/latest/download/immich-go_Linux_x86_64.tar.gz
tar xzf immich-go_Linux_x86_64.tar.gz
sudo mv immich-go /usr/local/bin/
chmod +x /usr/local/bin/immich-go
```

**Step 2: Verify installation**

```bash
immich-go version
```

Expected: Version number displayed

**Step 3: Set up environment variables**

Create `~/.immich-env`:

```bash
export IMMICH_API_KEY="your-api-key-here"
export IMMICH_URL="https://photos.paniland.com"
```

Source it:
```bash
source ~/.immich-env
```

**Step 4: Test API connection**

```bash
immich-go server-info
```

Expected: Immich server info displayed (version, users, etc.)

---

## Post-Implementation Checklist

After completing all tasks, verify:

- [ ] CT306 running and accessible at 192.168.1.182
- [ ] NVIDIA GPU visible in container (`nvidia-smi` works)
- [ ] Storage bind mount accessible at `/mnt/photos`
- [ ] PostgreSQL database created with extensions
- [ ] Redis running
- [ ] All three Immich services running (server, microservices, ML)
- [ ] Web UI accessible at https://photos.paniland.com
- [ ] Admin and partner accounts created
- [ ] API keys generated for both users
- [ ] Partner sharing enabled
- [ ] Caddy reverse proxy configured
- [ ] Database backups scheduled
- [ ] Restic backing up photos directory
- [ ] immich-go CLI tool installed and working
- [ ] Google Takeout exports requested
- [ ] Documentation updated (current-state.md, IP allocation)

---

## Next Steps: Photo Migration

Once infrastructure is deployed, proceed with migration following `docs/plans/photo-management-migration.md`:

1. **Wait for Google Takeout** (1-7 days)
2. **Mobile Cutover** - Install Immich apps, disable Google Photos backup
3. **Import Takeouts** - Use immich-go to import both partners' exports
4. **Validation** - Verify timeline, metadata, partner sharing
5. **Old Backups** - Deduplicate and import old backup drives
6. **Ongoing Workflow** - Establish maintenance routine

---

## Rollback Plan

If issues occur:

1. **Services not starting**: Check logs with `journalctl -u immich-*`
2. **GPU not working**: Verify passthrough config in `/etc/pve/lxc/306.conf`
3. **Database issues**: Check PostgreSQL logs, verify extensions installed
4. **Complete rollback**:
   ```bash
   terraform destroy -target=proxmox_virtual_environment_container.immich
   # Restore NVIDIA GPU to Jellyfin if needed
   ```

---

## Final Storage Architecture Summary

### SSD Storage (local-lvm thin pool - 1.65TB available)

**CT306 Root Disk (20GB):**
- OS and applications: ~8GB
- PostgreSQL database: ~5GB
- ML model cache: ~10GB
- Redis data: <1GB

**Thumbnails Volume (100GB SSD):**
- Path: `/var/lib/immich/thumbs`
- Device: `/dev/sdb`
- Purpose: Fast timeline browsing
- Expected usage: 10-15% of photo library size

**Encoded Video Volume (50GB SSD):**
- Path: `/var/lib/immich/encoded-video`
- Device: `/dev/sdc`
- Purpose: Smooth video playback
- Expected usage: 10-20% of video library size

**Upload/Profile (Container root):**
- Path: `/var/lib/immich/upload` and `/var/lib/immich/profile`
- Fast processing for active uploads
- Temporary staging before moving to library

### HDD Storage (MergerFS pool - 28TB available)

**Original Library (bind mount from host):**
- Host path: `/mnt/storage/media/photos/library`
- Container path: `/mnt/photos/library`
- Purpose: Long-term storage of original photos/videos
- Expected usage: Bulk of photo library (500GB-2TB+)

### Performance Benefits

✅ **Database on SSD**: Near-instantaneous metadata queries
✅ **Thumbnails on SSD**: Instant timeline scrolling (vs 10-15 sec on HDD)
✅ **Transcoded video on SSD**: Smooth playback without buffering
✅ **Originals on HDD**: Cost-effective storage, acceptable for sequential access

### Space Efficiency

**Total SSD allocated**: 170GB (20 + 100 + 50)
**SSD available after allocation**: ~1.48TB remaining
**HDD available**: 28TB for photo library growth

This architecture provides **optimal performance** while keeping **original photos on economical HDD storage**.

---

## Estimated Time

- Tasks 1-5: Infrastructure setup (30 min)
- Tasks 6-14: Ansible role development (2-3 hours)
- Task 15: Deployment (30-45 min depending on build time)
- Tasks 16-19: Configuration and documentation (45 min)
- Tasks 20-21: Migration prep (15 min)

**Total hands-on time**: ~5-6 hours
**Photo migration time**: Additional 6-8 weeks as per existing plan
