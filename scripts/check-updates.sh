#!/bin/bash
# Check for updates to pinned software versions
# Run quarterly or when you want to check for available updates
#
# Usage: ./scripts/check-updates.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "========================================="
echo "Version Check Report - $(date '+%Y-%m-%d %H:%M')"
echo "========================================="
echo ""

# Track overall status
UPDATES_AVAILABLE=0
ERRORS=0

# Function to check GitHub release
check_github_release() {
    local repo=$1
    local current=$2
    local name=$3
    local config_file=$4

    local latest
    latest=$(curl -s --max-time 10 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | grep -Po '"tag_name": "\K[^"]*' | sed 's/^v//' || echo "ERROR")

    if [[ "$latest" == "ERROR" ]] || [[ -z "$latest" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $name - Could not fetch latest version"
        ((ERRORS++))
        return
    fi

    if [[ "$latest" != "$current" ]]; then
        echo -e "${RED}[UPDATE]${NC} $name"
        echo "  Current: $current"
        echo "  Latest:  $latest"
        echo "  Config:  $config_file"
        echo "  URL:     https://github.com/$repo/releases"
        echo ""
        ((UPDATES_AVAILABLE++))
    else
        echo -e "${GREEN}[OK]${NC} $name @ $current"
    fi
}

# Function to display manual check required
manual_check() {
    local name=$1
    local current=$2
    local url=$3
    local config_file=$4

    echo -e "${YELLOW}[MANUAL]${NC} $name @ $current"
    echo "  Check:  $url"
    echo "  Config: $config_file"
    echo ""
}

echo "Checking GitHub Releases..."
echo "-------------------------------------------"

# Restic
RESTIC_CURRENT=$(grep -Po 'restic_version:\s*"\K[^"]+' "$REPO_ROOT/ansible/roles/restic_backup/defaults/main.yml" 2>/dev/null || echo "0.16.4")
check_github_release "restic/restic" "$RESTIC_CURRENT" "Restic" "ansible/roles/restic_backup/defaults/main.yml"

# MergerFS
MERGERFS_CURRENT=$(grep -Po 'mergerfs_version:\s*"\K[^"]+' "$REPO_ROOT/ansible/roles/proxmox_storage/defaults/main.yml" 2>/dev/null || echo "2.40.2")
check_github_release "trapexit/mergerfs" "$MERGERFS_CURRENT" "MergerFS" "ansible/roles/proxmox_storage/defaults/main.yml"

# SnapRAID
SNAPRAID_CURRENT=$(grep -Po 'snapraid_version:\s*"\K[^"]+' "$REPO_ROOT/ansible/roles/proxmox_storage/defaults/main.yml" 2>/dev/null || echo "12.3")
check_github_release "amadvance/snapraid" "$SNAPRAID_CURRENT" "SnapRAID" "ansible/roles/proxmox_storage/defaults/main.yml"

echo ""
echo "Manual Checks Required..."
echo "-------------------------------------------"

# MakeMKV (no GitHub releases, uses own website)
MAKEMKV_CURRENT=$(grep -Po 'makemkv_version:\s*"\K[^"]+' "$REPO_ROOT/ansible/roles/makemkv/defaults/main.yml" 2>/dev/null || echo "1.18.2")
manual_check "MakeMKV" "$MAKEMKV_CURRENT" "https://www.makemkv.com/download/" "ansible/roles/makemkv/defaults/main.yml"

# FileBot (commercial software, own website)
FILEBOT_CURRENT=$(grep -Po 'filebot_version:\s*"\K[^"]+' "$REPO_ROOT/ansible/roles/media_analyzer/defaults/main.yml" 2>/dev/null || echo "5.1.3")
manual_check "FileBot" "$FILEBOT_CURRENT" "https://www.filebot.net/download/" "ansible/roles/media_analyzer/defaults/main.yml"

echo "Terraform Providers..."
echo "-------------------------------------------"

if [[ -f "$REPO_ROOT/terraform/main.tf" ]]; then
    echo "Current constraints in terraform/main.tf:"
    grep -E '^\s+version\s*=' "$REPO_ROOT/terraform/main.tf" | head -10 || true
    echo ""
    echo "Run 'cd terraform && terraform init -upgrade' to check for updates"
else
    echo "Terraform configuration not found"
fi

echo ""
echo "========================================="
echo "Summary"
echo "========================================="

if [[ $UPDATES_AVAILABLE -gt 0 ]]; then
    echo -e "${RED}Updates available: $UPDATES_AVAILABLE${NC}"
else
    echo -e "${GREEN}All GitHub-tracked versions are current${NC}"
fi

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${YELLOW}Errors during check: $ERRORS${NC}"
fi

echo ""
echo "Next Steps:"
echo "1. Review any updates marked [UPDATE] above"
echo "2. Check the manual URLs for MakeMKV and FileBot"
echo "3. Test updates in non-production first if possible"
echo "4. Update version in Ansible defaults, then run playbook"
echo "5. Update docs/reference/version-tracking.md"
echo ""
echo "For detailed update procedures, see:"
echo "  docs/reference/version-tracking.md"

# Exit with status based on available updates
if [[ $UPDATES_AVAILABLE -gt 0 ]]; then
    exit 1
else
    exit 0
fi
