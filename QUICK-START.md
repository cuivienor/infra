# Quick Start: Repository Reorganization

## TL;DR

Run this to reorganize your repository:

```bash
bash reorganize.sh
```

Then review and commit:

```bash
git status
git commit -m "Reorganize repository structure for IaC work"
```

## What This Does

1. Creates new directory structure (terraform/, ansible/, organized docs/)
2. Moves all existing files to logical locations using `git mv`
3. Adds .gitignore for secrets and state files
4. Creates README files for navigation

## Safe to Run?

✅ **Yes!** The script:
- Uses `git mv` to preserve file history
- Doesn't delete anything
- Shows you all changes before committing
- Can be reverted with `git reset --hard HEAD` before committing

## Step-by-Step

### 1. Review the Plan
```bash
# Read the full organization plan
cat ORGANIZATION.md

# Or read the summary
cat REORGANIZATION-SUMMARY.md
```

### 2. Run the Migration
```bash
# Execute the reorganization
bash reorganize.sh

# Type 'yes' when prompted
```

### 3. Review Changes
```bash
# See what changed
git status

# See file movements
git diff --staged --stat

# See full diff (optional)
git diff --staged
```

### 4. Commit
```bash
# If everything looks good
git commit -m "Reorganize repository structure for IaC work"

# Push to remote (if you have one)
git push
```

## After Reorganization

### Find Your Files

| What You're Looking For | New Location |
|------------------------|--------------|
| Media scripts | `scripts/media/` |
| IaC strategy doc | `docs/reference/homelab-iac-strategy.md` |
| Setup guides | `docs/guides/` |
| Planning docs | `docs/plans/` |
| Current status notes | `notes/wip/CURRENT-STATUS.md` |

### Start IaC Work

Your IaC strategy doc is now at: `docs/reference/homelab-iac-strategy.md`

Ready to start? Create your first Terraform files:

```bash
# Create Terraform provider configuration
cd terraform
cat > providers.tf << 'TFEOF'
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}
TFEOF

# Create variables file
cat > variables.tf << 'TFEOF'
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}
# Add more variables as needed
TFEOF
```

### Update Script Paths (if needed)

If any of your scripts reference hardcoded paths, update them:

```bash
# Search for potential issues
grep -r "scripts/" scripts/ 2>/dev/null | grep -v ".git"

# Update paths as needed
```

## Rollback (if needed)

Before committing, you can undo everything:

```bash
# Undo all staged changes
git reset --hard HEAD

# Clean up untracked directories
git clean -fd
```

## Questions?

- **Structure details**: See `ORGANIZATION.md`
- **Full summary**: See `REORGANIZATION-SUMMARY.md`  
- **IaC strategy**: See `docs/reference/homelab-iac-strategy.md` (after running script)

## Current Status

- ✅ Organization plan created
- ✅ Migration script ready
- ✅ .gitignore configured
- ⏳ Waiting for you to run `bash reorganize.sh`
