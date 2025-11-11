# Homelab Repository Organization

## Directory Structure

```
homelab-notes/
├── README.md                    # Main repo overview
├── .gitignore                   # Ignore sensitive files
│
├── terraform/                   # Infrastructure as Code
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars        # Gitignored - your local values
│   └── containers/
│       ├── ripper.tf
│       ├── transcoder.tf
│       └── test.tf
│
├── ansible/                     # Configuration management
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yml
│   │   └── group_vars/
│   ├── vars/
│   │   └── secrets.yml         # Gitignored - encrypted vault
│   ├── roles/
│   │   ├── common/
│   │   ├── gpu_passthrough/
│   │   ├── optical_passthrough/
│   │   ├── transcoder/
│   │   └── ripper/
│   └── playbooks/
│       ├── site.yml
│       ├── host.yml
│       ├── ripper.yml
│       └── transcoder.yml
│
├── scripts/                     # Operational scripts
│   ├── media/                   # Media pipeline scripts
│   │   ├── rip-disc.sh
│   │   ├── transcode-media.sh
│   │   ├── organize-media.sh
│   │   └── (other media scripts)
│   ├── iac/                     # IaC helper scripts
│   │   ├── deploy.sh
│   │   ├── backup-state.sh
│   │   └── destroy-test.sh
│   └── utils/                   # One-off utilities
│       └── deploy-scripts.sh
│
├── docs/                        # Formal documentation
│   ├── guides/                  # How-to guides
│   │   ├── jellyfin-setup.md
│   │   ├── media-pipeline-v2.md
│   │   └── transcoding-container-setup.md
│   ├── reference/               # Reference material
│   │   ├── media-pipeline-quick-reference.md
│   │   ├── homelab-iac-strategy.md
│   │   └── current-state.md
│   ├── plans/                   # Planning documents
│   │   ├── directory-migration-plan.md
│   │   ├── migration-plan.md
│   │   └── homelab-media-pipeline-plan.md
│   └── archive/                 # Completed/obsolete docs
│       ├── homelab-media-pipeline-implementation.md
│       └── wsl2-ssh-connectivity-issue.md
│
├── notes/                       # Working notes and scratchpad
│   ├── wip/                     # Work in progress
│   │   └── CURRENT-STATUS.md
│   ├── ideas/                   # Future ideas and brainstorming
│   └── README.md                # How to use notes folder
│
└── .private-journal/            # Gitignored - personal notes
    └── (date-based entries)
```

## File Organization Principles

### 1. **terraform/** - Infrastructure as Code
- All Terraform configurations for Proxmox containers
- Gitignored: `.terraform/`, `*.tfstate`, `terraform.tfvars`
- Version controlled: `.tf` files, modules

### 2. **ansible/** - Configuration Management
- All Ansible playbooks and roles
- Gitignored: `.vault_pass`, `secrets.yml`
- Version controlled: Playbooks, roles, inventory structure

### 3. **scripts/** - Organized by Purpose
- **media/**: Active media pipeline scripts (ripping, transcoding, organizing)
- **iac/**: Infrastructure automation helpers
- **utils/**: One-off or utility scripts

### 4. **docs/** - Organized by Type
- **guides/**: Step-by-step how-to documentation
- **reference/**: Quick reference and strategy docs
- **plans/**: Planning and design documents
- **archive/**: Completed or superseded documentation

### 5. **notes/** - Dynamic Working Space
- **wip/**: Current work-in-progress notes
- **ideas/**: Future ideas and brainstorming
- Short-lived, frequently changing content
- Can be messy, more casual than docs/

### 6. **.private-journal/** - Personal Notes
- Gitignored by default
- Personal reflections, debugging notes, etc.

## Migration Plan

### Current Files → New Locations

**Documentation (to docs/):**
- `homelab-iac-strategy.md` → `docs/reference/homelab-iac-strategy.md`
- `homelab-media-pipeline-plan.md` → `docs/plans/homelab-media-pipeline-plan.md`
- `homelab-media-pipeline-implementation.md` → `docs/archive/` (if completed)
- `media-pipeline-v2-implementation.md` → `docs/guides/media-pipeline-v2.md`
- `media-pipeline-quick-reference.md` → `docs/reference/`
- `jellyfin-setup-guide.md` → `docs/guides/jellyfin-setup.md`
- `transcoding-container-setup.md` → `docs/guides/`
- `ct202-analyzer-setup.md` → `docs/guides/ct202-analyzer-setup.md`
- `directory-migration-plan.md` → `docs/plans/`
- `MIGRATION-PLAN.md` → `docs/plans/migration-plan.md`
- `wsl2-ssh-connectivity-issue.md` → `docs/archive/` (troubleshooting resolved)

**Scripts (reorganize in scripts/):**
- `rip-disc.sh` → `scripts/media/`
- `transcode-media.sh` → `scripts/media/`
- `transcode-queue.sh` → `scripts/media/`
- `organize-media.sh` → `scripts/media/`
- `organize-and-remux-movie.sh` → `scripts/media/`
- `organize-and-remux-tv.sh` → `scripts/media/`
- `filebot-process.sh` → `scripts/media/`
- `configure-makemkv.sh` → `scripts/media/`
- `analyze-media.sh` → `scripts/media/`
- `migrate-staging.sh` → `scripts/media/`
- `migrate-to-1-ripped.sh` → `scripts/media/`
- `promote-to-ready.sh` → `scripts/media/`
- `fix-current-names.sh` → `scripts/media/`
- `deploy-scripts.sh` → `scripts/utils/`

**Notes (to notes/):**
- `CURRENT-STATUS.md` → `notes/wip/CURRENT-STATUS.md`

## Usage Guidelines

### When to use **docs/** vs **notes/**

**Use docs/ when:**
- Writing formal documentation
- Creating guides for future reference
- Documenting completed work
- Content is relatively stable
- Others might read it

**Use notes/ when:**
- Brainstorming ideas
- Tracking current work status
- Quick scratch notes
- Temporary/frequently changing content
- Personal reminders

### Working with IaC

**Never commit:**
- Terraform state files
- Terraform variable files with secrets
- Ansible vault passwords
- API tokens or credentials

**Always commit:**
- Terraform `.tf` configurations
- Ansible playbooks and roles
- Ansible inventory structure (without IPs if sensitive)
- IaC helper scripts
- Documentation

## Next Steps

1. Review this organization plan
2. Run migration script to move files
3. Update any hardcoded paths in scripts
4. Test that scripts still work
5. Commit the reorganization
6. Begin IaC work in terraform/ and ansible/
