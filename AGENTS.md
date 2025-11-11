# Agents & AI Context

This file contains important context for AI assistants working on this repository. It helps maintain consistency and provides quick reference information.

---

## Repository Overview

**Purpose**: Homelab Infrastructure as Code, automation scripts, and documentation for my Proxmox-based media pipeline and container infrastructure.

**Current State**: Transitioning from manual container management to full IaC with Terraform and Ansible.

---

## Key Information

### Infrastructure

**Proxmox Host**:
- Hypervisor: Proxmox VE 8.x
- Storage: MergerFS pool mounted at `/mnt/storage`
- Hardware:
  - Intel Arc GPU (`/dev/dri/card0`, `/dev/dri/renderD128`) - for transcoding
  - Optical drive (`/dev/sr0`, `/dev/sg0`) - for Blu-ray ripping
  - Optional: NVIDIA 1080 (if used)

**Container Architecture**:
- LXC containers (privileged for hardware passthrough)
- Network: DHCP on vmbr0 bridge
- Storage mount: `/mnt/storage` bind-mounted from host
- Base template: Debian 12

**Key Containers**:
- **Ripper**: MakeMKV for Blu-ray ripping (optical drive passthrough)
- **Transcoder**: FFmpeg/HandBrake with GPU acceleration (Arc GPU passthrough)
- Future: Jellyfin, monitoring, etc.

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
- All scripts expect to run as `media` user
- Scripts handle ripping, transcoding, organizing, and migration

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

**Important Files**:
- IaC Strategy: `docs/reference/homelab-iac-strategy.md`
- Current Status: `notes/wip/CURRENT-STATUS.md`

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
2. Add to `ansible/inventory/hosts.yml`
3. Create playbook in `ansible/playbooks/<name>.yml`
4. Create role(s) if needed in `ansible/roles/<role_name>/`
5. Test deployment
6. Document in `docs/guides/`

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

**GPU (Intel Arc)**:
- Requires `intel-media-va-driver` on host
- Devices: `/dev/dri/card0`, `/dev/dri/renderD128`
- Add `video` and `render` groups in container
- Verify with: `vainfo --display drm --device /dev/dri/renderD128`

**Optical Drive**:
- Devices: `/dev/sr0`, `/dev/sg0`, `/dev/sg1`
- Add `cdrom` group in container
- LXC config needs cgroup rules and mount entries
- Must be configured via Ansible (not Terraform)

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

# Edit vault
ansible-vault edit vars/secrets.yml
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

---

## Project Goals

### Short Term

- [ ] Complete Phase 1: Test container with Terraform + Ansible
- [ ] Import existing ripper container to IaC
- [ ] Import existing transcoder container to IaC
- [ ] Document device passthrough process
- [ ] Create deployment automation script

### Medium Term

- [ ] Automate host configuration with Ansible
- [ ] Create backup/restore procedures
- [ ] Test disaster recovery workflow
- [ ] Add monitoring container
- [ ] Migrate Jellyfin to container

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

### 2025-01-11
- Initial AGENTS.md creation
- Repository reorganized for IaC work
- Directory structure established
- Documentation organized by type
- Scripts categorized by purpose

---

## Contact & Context

**Maintained by**: cuiv (homelab owner)
**Repository**: homelab-notes
**Primary use**: Personal homelab infrastructure and media pipeline automation
**Status**: Active development, transitioning to IaC

---

*Last updated: 2025-01-11*
