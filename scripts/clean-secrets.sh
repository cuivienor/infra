#!/bin/bash
# clean-secrets.sh - Remove secrets from git history using BFG Repo-Cleaner
#
# This script:
# 1. Creates a mirror clone of the repository
# 2. Runs BFG to replace secrets with REDACTED
# 3. Cleans up git objects
# 4. Optionally force-pushes to remote
#
# Prerequisites:
# - Java 8+ installed
# - BFG jar at ~/.local/bin/bfg.jar
# - scripts/bfg-replacements.txt with secrets to redact

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BFG_JAR="$HOME/.local/bin/bfg.jar"
REPLACEMENTS="$SCRIPT_DIR/bfg-replacements.txt"
MIRROR_DIR="/tmp/infra-mirror-$(date +%s)"

# Verify prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."

    if ! command -v java &> /dev/null; then
        echo -e "${RED}Error:${NC} Java not found. Install Java 8+ first."
        exit 1
    fi

    if [[ ! -f "$BFG_JAR" ]]; then
        echo -e "${RED}Error:${NC} BFG not found at $BFG_JAR"
        echo "Download it with:"
        echo "  curl -sSL -o ~/.local/bin/bfg.jar https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar"
        exit 1
    fi

    if [[ ! -f "$REPLACEMENTS" ]]; then
        echo -e "${RED}Error:${NC} Replacements file not found at $REPLACEMENTS"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} All prerequisites met"
}

# Show what will be replaced
show_replacements() {
    echo ""
    echo "Secrets to be replaced:"
    grep -v '^#' "$REPLACEMENTS" | grep -v '^$' | while read -r line; do
        # Show first/last 3 chars of secret for verification
        secret="${line%%==>*}"
        if [[ ${#secret} -gt 6 ]]; then
            masked="${secret:0:3}...${secret: -3}"
        else
            masked="***"
        fi
        echo "  - $masked ==> REDACTED"
    done
    echo ""
}

# Create mirror clone
create_mirror() {
    echo "Creating mirror clone at $MIRROR_DIR..."
    git clone --mirror "$REPO_DIR" "$MIRROR_DIR"
    echo -e "${GREEN}✓${NC} Mirror created"
}

# Run BFG
run_bfg() {
    echo ""
    echo "Running BFG Repo-Cleaner..."
    cd "$MIRROR_DIR"
    java -jar "$BFG_JAR" --replace-text "$REPLACEMENTS" --no-blob-protection .
    echo -e "${GREEN}✓${NC} BFG completed"
}

# Clean up git objects
cleanup_git() {
    echo ""
    echo "Cleaning up git objects..."
    cd "$MIRROR_DIR"
    git reflog expire --expire=now --all
    git gc --prune=now --aggressive
    echo -e "${GREEN}✓${NC} Git cleanup completed"
}

# Verify the fix
verify_fix() {
    echo ""
    echo "Verifying secrets are removed..."
    cd "$MIRROR_DIR"

    # Check if any secrets remain
    local found=0
    grep -v '^#' "$REPLACEMENTS" | grep -v '^$' | while read -r line; do
        secret="${line%%==>*}"
        if git log --all -p 2>/dev/null | grep -q "$secret"; then
            echo -e "${RED}✗${NC} Secret still found: ${secret:0:3}..."
            found=1
        fi
    done

    if [[ $found -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} All secrets removed from history"
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    echo -e "${YELLOW}=== NEXT STEPS ===${NC}"
    echo ""
    echo "The cleaned repository is at: $MIRROR_DIR"
    echo ""
    echo "To apply changes:"
    echo ""
    echo "  1. Verify the fix:"
    echo "     cd $MIRROR_DIR"
    echo "     git log --all -p | grep -i 'authtoken'  # Should find nothing"
    echo ""
    echo "  2. Force push to remote (THIS REWRITES HISTORY):"
    echo "     cd $MIRROR_DIR"
    echo "     git push --force"
    echo ""
    echo "  3. Update your local working copy:"
    echo "     cd $REPO_DIR"
    echo "     git fetch origin"
    echo "     git reset --hard origin/main"
    echo ""
    echo "  4. Clean up the mirror:"
    echo "     rm -rf $MIRROR_DIR"
    echo ""
    echo -e "${RED}WARNING:${NC} Force pushing rewrites history for all collaborators."
    echo "         They will need to re-clone or reset their local copies."
    echo ""
    echo -e "${RED}IMPORTANT:${NC} Old commits may still be accessible on GitHub via direct SHA URLs"
    echo "           until GitHub garbage collects them. Consider contacting GitHub support"
    echo "           if these are highly sensitive secrets, or rotate them regardless."
}

# Main
main() {
    echo "========================================"
    echo "  BFG Secret Cleaner for infra repo"
    echo "========================================"
    echo ""

    check_prerequisites
    show_replacements

    read -p "Proceed with cleaning? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    create_mirror
    run_bfg
    cleanup_git
    verify_fix
    show_next_steps
}

main "$@"
