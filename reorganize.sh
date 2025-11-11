#!/bin/bash
# Script to reorganize homelab-notes repository
# Run with: bash reorganize.sh

set -e  # Exit on error

echo "=== Homelab Repository Reorganization ==="
echo
echo "This script will reorganize your files according to ORGANIZATION.md"
echo "All moves will use 'git mv' to preserve history"
echo
read -p "Continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

echo
echo "Creating directory structure..."

# Create new directories
mkdir -p terraform/containers
mkdir -p ansible/{inventory/group_vars,vars,roles,playbooks}
mkdir -p scripts/{media,iac,utils}
mkdir -p docs/{guides,reference,plans,archive}
mkdir -p notes/{wip,ideas}

echo "Moving documentation files..."

# Documentation to docs/reference
git mv homelab-iac-strategy.md docs/reference/
git mv media-pipeline-quick-reference.md docs/reference/

# Documentation to docs/guides  
git mv jellyfin-setup-guide.md docs/guides/jellyfin-setup.md
git mv transcoding-container-setup.md docs/guides/
git mv media-pipeline-v2-implementation.md docs/guides/media-pipeline-v2.md

# Add untracked file first if it exists
if [[ -f ct202-analyzer-setup.md ]]; then
    git add ct202-analyzer-setup.md
    git mv ct202-analyzer-setup.md docs/guides/
fi

# Documentation to docs/plans
git mv directory-migration-plan.md docs/plans/
git mv MIGRATION-PLAN.md docs/plans/migration-plan.md
git mv homelab-media-pipeline-plan.md docs/plans/

# Documentation to docs/archive (completed/obsolete)
git mv homelab-media-pipeline-implementation.md docs/archive/
git mv wsl2-ssh-connectivity-issue.md docs/archive/

echo "Moving scripts..."

# Move media scripts (using a loop to handle them all)
for script in rip-disc.sh transcode-media.sh transcode-queue.sh \
              organize-media.sh organize-and-remux-movie.sh organize-and-remux-tv.sh \
              filebot-process.sh configure-makemkv.sh analyze-media.sh \
              migrate-staging.sh migrate-to-1-ripped.sh promote-to-ready.sh \
              fix-current-names.sh; do
    if [[ -f "scripts/$script" ]]; then
        git mv "scripts/$script" "scripts/media/"
    fi
done

# Move utility scripts
if [[ -f deploy-scripts.sh ]]; then
    git mv deploy-scripts.sh scripts/utils/
fi

echo "Moving notes..."

# Move working notes
git mv CURRENT-STATUS.md notes/wip/

echo "Creating README files..."

# Create notes README
cat > notes/README.md << 'EOF'
# Notes

This directory contains working notes and scratchpad content.

## Structure

- **wip/**: Work in progress notes and current status tracking
- **ideas/**: Future ideas, brainstorming, experimental thoughts

## Guidelines

- Keep it casual and messy - this is your thinking space
- Move content to docs/ when it becomes formal/stable
- Clean up completed WIP items periodically
- Date your notes for easy tracking
EOF

git add notes/README.md

# Create main README
cat > README.md << 'EOF'
# Homelab Infrastructure & Media Pipeline

This repository contains Infrastructure as Code, automation scripts, and documentation for my homelab setup.

## Quick Links

- **[Organization Guide](ORGANIZATION.md)** - How this repo is structured
- **[IaC Strategy](docs/reference/homelab-iac-strategy.md)** - Terraform & Ansible plan
- **[Media Pipeline Guide](docs/guides/media-pipeline-v2.md)** - Media workflow documentation

## Repository Structure

```
├── terraform/          # Infrastructure as Code (Proxmox containers)
├── ansible/           # Configuration management (playbooks & roles)
├── scripts/           # Operational scripts
│   ├── media/        # Media pipeline automation
│   ├── iac/          # Infrastructure helpers
│   └── utils/        # Utilities
├── docs/             # Formal documentation
│   ├── guides/       # How-to guides
│   ├── reference/    # Quick references
│   ├── plans/        # Planning documents
│   └── archive/      # Completed/obsolete docs
└── notes/            # Working notes and WIP
```

## Getting Started

### Media Pipeline Scripts

All media processing scripts are in `scripts/media/`:
- `rip-disc.sh` - Rip Blu-ray discs with MakeMKV
- `transcode-media.sh` - Transcode videos with hardware acceleration
- `organize-media.sh` - Organize media files with FileBot

See [Media Pipeline Quick Reference](docs/reference/media-pipeline-quick-reference.md) for details.

### Infrastructure as Code

Terraform and Ansible configurations for managing Proxmox containers:
- See [IaC Strategy](docs/reference/homelab-iac-strategy.md) for the plan
- `terraform/` - Container definitions
- `ansible/` - Configuration playbooks

## Contributing

This is a personal homelab repo, but feel free to fork and adapt for your own use!
EOF

if [[ ! -f README.md ]] || [[ $(git status --porcelain README.md | wc -l) -gt 0 ]]; then
    git add README.md
fi

echo
echo "=== Reorganization Complete ==="
echo
echo "Summary of changes:"
git status --short
echo
echo "Next steps:"
echo "1. Review the changes: git status"
echo "2. Review what was moved: git diff --staged"
echo "3. Commit the changes: git commit -m 'Reorganize repository structure'"
echo "4. If you have any scripts that reference old paths, update them"
echo
echo "The new structure is documented in ORGANIZATION.md"
