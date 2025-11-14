# Agents & AI Context

This file contains important context for AI assistants working on this repository. It helps maintain consistency and provides quick reference information.

---

## Repository Overview

**Purpose**: Homelab Infrastructure as Code, automation scripts, and documentation for my Proxmox-based media pipeline and container infrastructure.

**Current State**: Transitioning from manual container management to full IaC with Terraform and Ansible.

---

## Working Environment

**IMPORTANT**: Commands are typically executed from a client machine (laptop/workstation), NOT directly on the Proxmox host.

### SSH Access Required

- **Proxmox Host**: `ssh root@192.168.1.56` or `ssh root@homelab`
- **Containers**: `ssh root@<container-ip>` or `ssh root@<container-hostname>`

### Command Execution Patterns

**❌ WRONG** (will fail if not on Proxmox host):
```bash
pct list
cat /etc/pve/lxc/305.conf
```

**✅ CORRECT** (works from client):
```bash
ssh root@homelab "pct list"
ssh root@homelab "cat /etc/pve/lxc/305.conf"
```

**Container commands**:
```bash
ssh root@192.168.1.85 "systemctl status jellyfin"
ssh root@homelab "pct enter 305 -- systemctl status jellyfin"
```

### When Working Locally

The repository is located at `/home/cuiv/dev/homelab-notes/` on the client machine. Terraform and Ansible commands should be run from this directory, which will connect to the Proxmox host remotely.

---

## Key Information

### Infrastructure

**Proxmox Host**:
- **Hostname**: `homelab` (192.168.1.56)
- **Hypervisor**: Proxmox VE 8.4.14 (kernel 6.8.12-10-pve)
- **Hardware**: Intel Core i5-9600K (6 cores), 32GB RAM
- **Storage**: MergerFS pool (35TB total, 4.1TB used) mounted at `/mnt/storage`
  - 3x data disks (9.1T + 9.1T + 17T)
  - 1x parity disk (17T)
- **GPUs**:
  - **Intel Arc A380** (`/dev/dri/card1`, `/dev/dri/renderD128`) - Primary for transcoding
  - **NVIDIA GTX 1080** (`/dev/dri/card0`, `/dev/dri/renderD129`) - Secondary/Display
- **Optical Drive**: `/dev/sr0` (block), `/dev/sg4` (SCSI generic) - for Blu-ray ripping

**Container Architecture**:
- LXC containers (privileged for hardware passthrough)
- Network: DHCP on vmbr0 bridge (192.168.1.x/24)
- Storage mount: `/mnt/storage` bind-mounted from host
- Base template: Debian 12

**Active Containers** (All IaC - 300 Range):
- **CT300 backup** (192.168.1.58): Restic + Backrest UI for automated backups to Backblaze B2
- **CT301 samba** (192.168.1.82): Samba file server for network shares
- **CT302 ripper** (192.168.1.70): MakeMKV with optical drive passthrough
- **CT303 analyzer** (192.168.1.73): Media analysis, remuxing, and organization tools
- **CT304 transcoder** (192.168.1.77): FFmpeg with Intel Arc GPU passthrough
- **CT305 jellyfin** (192.168.1.85): Media server with dual GPU support (Intel Arc + NVIDIA)

### Media Pipeline

**Workflow**:
1. Rip disc → `/mnt/storage/media/staging/0-raw/`
2. Transcode → `/mnt/storage/media/staging/1-ripped/`
3. Organize with FileBot → `/mnt/storage/media/movies/` or `/mnt/storage/media/tv/`
4. Serve via Jellyfin

**Media User**:
- Username: `media`
- UID/GID: `1000:1000` (standardized across all containers and host)
- Purpose: Consistent ownership for media files across containers

**Scripts Location**: `scripts/media/`
- **Organized structure**: `production/`, `utilities/`, `migration/`, `archive/`
- All scripts expect to run as `media` user
- Scripts handle ripping, transcoding, organizing, and migration
- See `scripts/media/README.md` for complete documentation

### IaC Strategy

**Approach**: Progressive migration
- Phase 1: Test container to learn workflow ⏳
- Phase 2: Import existing production containers ⏳
- Phase 3: Automate host configuration ⏳
- Phase 4: Full disaster recovery capability ⏳

**Technology Stack**:
- **Terraform** (BPG provider): Container provisioning
- **Ansible**: Configuration management and device passthrough
- **Git**: Version control
- **Ansible Vault**: Secrets management

**Important Reference Files**:
- **IaC Strategy**: `docs/reference/homelab-iac-strategy.md` - Complete IaC implementation plan
- **Current State** (static): `docs/reference/current-state.md` - Full hardware/software inventory
- **System Snapshot** (dynamic): `notes/wip/SYSTEM-SNAPSHOT.md` - Running state, recent changes
- **Current Work**: `notes/wip/CURRENT-STATUS.md` - Active tasks and progress

💡 **Always read** `docs/reference/current-state.md` first for complete system context!

---

## Repository Structure

```
homelab-notes/
├── terraform/          # Infrastructure as Code definitions
│   └── containers/    # LXC container configurations
├── ansible/           # Configuration management
│   ├── inventory/    # Host and container inventory
│   ├── roles/        # Reusable Ansible roles
│   ├── playbooks/    # Ansible playbooks
│   └── vars/         # Variables (secrets.yml is encrypted)
├── scripts/
│   ├── media/        # Media pipeline automation (rip, transcode, organize)
│   ├── iac/          # IaC helper scripts (deploy, backup)
│   └── utils/        # Utility scripts
├── docs/
│   ├── guides/       # Step-by-step how-to documentation
│   ├── reference/    # Quick reference and strategy docs
│   ├── plans/        # Planning and design documents
│   └── archive/      # Completed or superseded documentation
└── notes/
    ├── wip/          # Work in progress notes and current status
    └── ideas/        # Future ideas and brainstorming
```

---

## Working Conventions

### When Creating Files

**Terraform**:
- Place in `terraform/` or `terraform/containers/`
- Use `.tf` extension
- Follow HCL formatting standards
- Never commit `terraform.tfvars` (contains secrets)

**Ansible**:
- Playbooks in `ansible/playbooks/`
- Roles in `ansible/roles/<role_name>/`
- Follow standard role structure (tasks/, defaults/, handlers/, templates/, files/)
- Encrypt secrets with Ansible Vault

**Scripts**:
- Media pipeline scripts → `scripts/media/`
- IaC automation → `scripts/iac/`
- One-off utilities → `scripts/utils/`
- Make executable with `chmod +x`
- Include shebang (`#!/bin/bash`)

**Documentation**:
- How-to guides → `docs/guides/`
- Strategy/reference → `docs/reference/`
- Planning docs → `docs/plans/`
- Completed work → `docs/archive/`

**Notes**:
- Current work → `notes/wip/`
- Future ideas → `notes/ideas/`
- Can be informal and messy

### Security

**Ansible Vault Password**:
- **Location**: `.vault_pass` in repository root (`/home/cuiv/dev/homelab-notes/.vault_pass`)
- **NOT** in `~/.vault_pass` (repo-specific, not global)
- **Usage**: `--vault-password-file .vault_pass` (from repo root) or `--vault-password-file ../.vault_pass` (from ansible/)
- **Permissions**: `chmod 600 .vault_pass`

**Never Commit**:
- Terraform state files (`*.tfstate`)
- Terraform variables with secrets (`terraform.tfvars`)
- Ansible vault passwords (`.vault_pass`)
- Unencrypted secrets (`*secret*`, `*token*`, `*password*`)
- Private journal entries (`.private-journal/`)

**Always Commit**:
- Terraform configurations (`.tf` files)
- Ansible playbooks and roles
- Ansible inventory structure (IPs can be parameterized)
- Scripts (ensure no hardcoded credentials)
- Documentation
- Encrypted vault files (e.g., `*_secrets.yml` after encryption)

### Git Workflow

**Commit Messages**:
- Use clear, descriptive messages
- Format: `<type>: <description>`
- Types: feat, fix, docs, refactor, chore, test

**Examples**:
```
feat: Add Terraform configuration for ripper container
fix: Correct GPU device passthrough in transcoder role
docs: Update media pipeline quick reference
refactor: Reorganize Ansible roles for better reusability
chore: Update .gitignore for new secrets pattern
```

---

## Common Tasks

### Starting IaC Work

1. Read the strategy: `docs/reference/homelab-iac-strategy.md`
2. Check current status: `notes/wip/CURRENT-STATUS.md`
3. Create Terraform configs in `terraform/`
4. Create Ansible playbooks in `ansible/`
5. Test with test container first (CTID 199)
6. Document as you go

### Adding a New Container

1. Define in `terraform/containers/<name>.tf`
2. Add to `ansible/inventory/hosts.yml` with IP address
3. Create playbook in `ansible/playbooks/<name>.yml`
4. Create role(s) if needed in `ansible/roles/<role_name>/`
5. Device passthrough must be done via Ansible (add to LXC config on host)
6. Test deployment
7. Document in `docs/guides/`
8. Update `docs/reference/current-state.md` and `notes/wip/SYSTEM-SNAPSHOT.md`

### Working on Media Pipeline

1. Scripts are in `scripts/media/`
2. Always run as `media` user (UID 1000)
3. Test changes in staging directory first
4. Update documentation in `docs/reference/media-pipeline-quick-reference.md`

### Updating Documentation

- **New guide**: Create in `docs/guides/`
- **Update strategy**: Edit `docs/reference/`
- **Planning**: Add to `docs/plans/`
- **Obsolete doc**: Move to `docs/archive/`
- **Quick notes**: Use `notes/wip/` or `notes/ideas/`

---

## Known Issues & Limitations

### LXC Containers

- **No cloud-init support**: Must use Ansible for post-creation configuration
- **Network timing**: Containers may need manual network activation after first boot
- **Device passthrough**: Requires host-side configuration (cgroup rules)
- **Privileged required**: For GPU and optical drive passthrough

### Hardware Passthrough

**GPU (Intel Arc A380)**:
- **Host Devices**: `/dev/dri/card1`, `/dev/dri/renderD128`
- **Driver**: i915 kernel module (Intel iHD VA-API driver)
- **Container Groups**: `video` (226), `render` (104)
- **Used By**: CT201 (transcoder-new)
- **LXC Config**:
  ```
  lxc.cgroup2.devices.allow: c 226:0 rwm      # card0
  lxc.cgroup2.devices.allow: c 226:128 rwm    # renderD128
  lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
  ```
- **Verify**: `vainfo --display drm --device /dev/dri/renderD128`
- **Status**: ✅ Working (VA-API 1.17)

**Optical Drive (Blu-ray)**:
- **Host Devices**: `/dev/sr0` (block, major 11:0), `/dev/sg4` (SCSI generic, major 21:4)
- **Container Group**: `cdrom` (24)
- **Used By**: CT200 (ripper-new)
- **LXC Config**:
  ```
  lxc.cgroup2.devices.allow: c 11:0 rwm       # /dev/sr0
  lxc.cgroup2.devices.allow: c 21:4 rwm       # /dev/sg4
  lxc.mount.entry: /dev/sr0 dev/sr0 none bind,optional,create=file
  lxc.mount.entry: /dev/sg4 dev/sg4 none bind,optional,create=file
  ```
- **Verify**: `makemkvcon info disc:0`
- **Status**: ✅ Working
- **Note**: Must be configured via Ansible (not Terraform)

### MergerFS

- Host-level configuration only
- Mounted at `/mnt/storage` on host
- Bind-mounted to containers
- Permission issues with unprivileged containers (hence using privileged)

---

## Quick Reference Commands

### Proxmox

```bash
# List containers
pct list

# Enter container
pct enter <CTID>

# Start/stop container
pct start <CTID>
pct stop <CTID>

# View container config
cat /etc/pve/lxc/<CTID>.conf
```

### Terraform

```bash
# Initialize
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Import existing resource
terraform import proxmox_virtual_environment_container.<name> <node>/lxc/<CTID>
```

### Ansible

```bash
# Test connectivity
ansible <host> -m ping

# Run playbook
ansible-playbook playbooks/<name>.yml

# Run with tags
ansible-playbook playbooks/site.yml --tags ripper

# Check mode (dry run)
ansible-playbook playbooks/<name>.yml --check

# Edit vault (vault password is in repo root: .vault_pass)
ansible-vault edit vars/secrets.yml --vault-password-file ../.vault_pass
```

### Media Scripts

```bash
# Run as media user
sudo -u media /path/to/script.sh

# Or switch to media user first
su - media
./scripts/media/rip-disc.sh
```

---

## Useful File Locations

### Configuration

- **Proxmox LXC configs**: `/etc/pve/lxc/<CTID>.conf` (on host)
- **MergerFS mount**: `/etc/fstab` (on host)
- **IaC strategy**: `docs/reference/homelab-iac-strategy.md`
- **Current work status**: `notes/wip/CURRENT-STATUS.md`

### Media Directories

- **Staging**: `/mnt/storage/media/staging/`
  - `0-raw/` - Raw MakeMKV output
  - `1-ripped/` - Transcoded files
  - `2-ready/` - Organized and ready for Jellyfin
- **Library**: `/mnt/storage/media/movies/`, `/mnt/storage/media/tv/`

### Scripts

- **Media pipeline**: `scripts/media/`
- **IaC helpers**: `scripts/iac/`
- **Utilities**: `scripts/utils/`

### Backups

- **Configuration**: `/etc/restic/` (on host)
- **Backup logs**: `/var/log/restic/` (on host)
- **Ansible role**: `ansible/roles/restic_backup/`
- **Documentation**: `docs/guides/backup-setup.md`
- **Quick reference**: `docs/reference/backup-quick-reference.md`

---

## Project Goals

### Short Term

- [x] Repository reorganization for IaC work
- [x] Comprehensive system documentation (current-state.md)
- [x] Complete Phase 1: Test container with Terraform + Ansible
- [x] Import all production containers to Terraform (CT300-305)
- [x] Create Ansible roles for device passthrough automation
- [x] Migrate all containers to IaC (300 range)
- [x] Remove legacy containers (CT100, CT101, CT102, CT200, CT201, CT202)
- [ ] Create deployment automation script
- [ ] Test end-to-end media pipeline with new containers

### Medium Term

- [ ] Automate host configuration with Ansible
- [x] Create backup/restore procedures (restic + Backblaze B2)
- [ ] Test disaster recovery workflow
- [ ] Add monitoring container

### Long Term

- [ ] Full infrastructure reproducibility
- [ ] Automated testing for playbooks
- [ ] CI/CD for IaC changes
- [ ] Documentation site generation
- [ ] Multi-host setup (if expanding)

---

## Tips for AI Agents

1. **Always check current status** in `notes/wip/CURRENT-STATUS.md` before starting work
2. **Read the IaC strategy** at `docs/reference/homelab-iac-strategy.md` for context
3. **Follow the directory structure** - don't create files in the wrong locations
4. **Preserve git history** - use `git mv` when moving files
5. **Security first** - never create files with secrets in unencrypted form
6. **Test containers first** - use CTID 199 for testing before touching production
7. **Document as you go** - update docs when adding features
8. **Use descriptive commit messages** - future you will thank you
9. **Scripts should be idempotent** - safe to run multiple times
10. **When in doubt, ask** - better to clarify than make assumptions

---

## Changelog

### 2025-11-12
- ✅ **MAJOR MILESTONE**: Full migration to IaC completed!
- ✅ Removed all legacy containers (CT101, CT200, CT201, CT202)
- ✅ All containers now managed by Terraform + Ansible (CT300-305)
- ✅ Reclaimed 48GB disk space from legacy containers
- ✅ Updated documentation to reflect IaC-only environment
- 📊 Final state: 6 active containers, all infrastructure as code

### 2025-11-11
- ✅ Repository reorganized for IaC work
- ✅ Directory structure established (terraform/, ansible/, organized docs/)
- ✅ Documentation organized by type (guides, reference, plans, archive)
- ✅ Scripts categorized by purpose (media, iac, utils)
- ✅ Comprehensive system inspection completed
- ✅ Created `docs/reference/current-state.md` with full hardware/software inventory
- ✅ Created `notes/wip/SYSTEM-SNAPSHOT.md` for tracking dynamic state
- ✅ Updated AGENTS.md with actual discovered system details
- 📊 Discovered: Intel Arc A380 + NVIDIA GTX 1080, 35TB MergerFS pool
- 📊 Deployed first IaC containers (CT300-305)

---

## Contact & Context

**Maintained by**: cuiv (homelab owner)
**Repository**: homelab-notes
**Primary use**: Personal homelab infrastructure and media pipeline automation
**Status**: Active development, transitioning to IaC

---

*Last updated: 2025-11-11 - System inspection and comprehensive documentation completed*
