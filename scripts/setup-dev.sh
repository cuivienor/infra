#!/bin/bash
# setup-dev.sh - Install development tools for homelab-notes repository
#
# Supports: Arch Linux, macOS (Homebrew)
# Installs: shellcheck, shfmt, yamllint, ansible-lint, pre-commit, tflint (optional)
#           sops, age, bitwarden-cli, direnv (secrets management)
#
# Usage:
#   ./scripts/setup-dev.sh             # Install all tools
#   ./scripts/setup-dev.sh --check     # Check what's installed
#   ./scripts/setup-dev.sh --setup-secrets  # Restore secrets from Bitwarden

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif command -v pacman &> /dev/null; then
        echo "arch"
    elif command -v apt-get &> /dev/null; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Check if a command exists
check_cmd() {
    command -v "$1" &> /dev/null
}

# Print status
print_status() {
    local tool="$1"
    if check_cmd "$tool"; then
        echo -e "  ${GREEN}✓${NC} $tool"
    else
        echo -e "  ${RED}✗${NC} $tool"
    fi
}

# Check current installation status
check_tools() {
    echo "Development tool status:"
    echo ""
    echo "Package managers:"
    print_status "pacman"
    print_status "brew"
    print_status "pip"
    echo ""
    echo "Core tools:"
    print_status "terraform"
    print_status "ansible"
    print_status "ansible-playbook"
    echo ""
    echo "Linters & formatters:"
    print_status "shellcheck"
    print_status "shfmt"
    print_status "yamllint"
    print_status "ansible-lint"
    print_status "tflint"
    echo ""
    echo "Git hooks:"
    print_status "pre-commit"

    if [[ -f ".git/hooks/pre-commit" ]]; then
        echo -e "  ${GREEN}✓${NC} pre-commit hooks installed"
    else
        echo -e "  ${YELLOW}!${NC} pre-commit hooks not installed (run 'pre-commit install')"
    fi

    echo ""
    echo "Secrets management:"
    print_status "sops"
    print_status "age"
    print_status "bw"
    print_status "direnv"

    # Get script directory for relative paths
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    echo ""
    echo "Secrets files:"
    if [[ -f "$script_dir/../terraform/.sops-key" ]]; then
        echo -e "  ${GREEN}✓${NC} SOPS age key (terraform/.sops-key)"
    else
        echo -e "  ${YELLOW}!${NC} SOPS age key not found (run --setup-secrets)"
    fi

    if [[ -f "$script_dir/../ansible/.vault_pass" ]]; then
        echo -e "  ${GREEN}✓${NC} Ansible vault password (ansible/.vault_pass)"
    else
        echo -e "  ${YELLOW}!${NC} Ansible vault password not found (run --setup-secrets)"
    fi

    echo ""
    echo "Environment (via direnv):"
    if [[ -n "${SOPS_AGE_KEY_FILE:-}" ]]; then
        echo -e "  ${GREEN}✓${NC} SOPS_AGE_KEY_FILE is set"
    else
        echo -e "  ${YELLOW}!${NC} SOPS_AGE_KEY_FILE not set (run 'direnv allow')"
    fi

    if [[ -n "${ANSIBLE_VAULT_PASSWORD_FILE:-}" ]]; then
        echo -e "  ${GREEN}✓${NC} ANSIBLE_VAULT_PASSWORD_FILE is set"
    else
        echo -e "  ${YELLOW}!${NC} ANSIBLE_VAULT_PASSWORD_FILE not set (run 'direnv allow')"
    fi
}

# Install on Arch Linux
install_arch() {
    echo "Installing tools for Arch Linux..."

    # System packages
    echo "Installing system packages..."
    sudo pacman -S --needed --noconfirm \
        shellcheck \
        shfmt \
        yamllint \
        python-pip

    # Secrets management tools
    echo "Installing secrets management tools..."
    sudo pacman -S --needed --noconfirm age sops direnv

    # Bitwarden CLI (check if available, suggest alternatives)
    if ! check_cmd bw; then
        echo -e "${YELLOW}Note:${NC} Bitwarden CLI not found."
        echo "  Install from AUR: yay -S bitwarden-cli"
        echo "  Or via npm: npm install -g @bitwarden/cli"
    fi

    # Python tools (user-local)
    echo "Installing Python tools..."
    pip install --user --upgrade --break-system-packages \
        ansible-lint \
        pre-commit

    # Ensure ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo -e "${YELLOW}Warning:${NC} ~/.local/bin is not in your PATH"
        echo "Add this to your ~/.bashrc or ~/.zshrc:"
        echo '  export PATH="$HOME/.local/bin:$PATH"'
    fi
}

# Install on macOS
install_macos() {
    echo "Installing tools for macOS..."

    # Check for Homebrew
    if ! check_cmd brew; then
        echo -e "${RED}Error:${NC} Homebrew not found. Install from https://brew.sh"
        exit 1
    fi

    # Homebrew packages
    echo "Installing Homebrew packages..."
    brew install \
        shellcheck \
        shfmt \
        yamllint \
        ansible-lint \
        pre-commit \
        tflint

    # Secrets management tools
    echo "Installing secrets management tools..."
    brew install sops age bitwarden-cli direnv

    # Note: ansible-lint and pre-commit available via brew on macOS
}

# Setup secrets from Bitwarden
setup_secrets() {
    # Get script directory for relative paths
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local sops_key="$script_dir/../terraform/.sops-key"
    local vault_pass="$script_dir/../ansible/.vault_pass"

    # Check Bitwarden CLI
    if ! check_cmd bw; then
        echo -e "${RED}Error:${NC} Bitwarden CLI not installed"
        echo "Install it first, then run this again."
        return 1
    fi

    # Check if logged in and unlocked
    if ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
        echo -e "${RED}Error:${NC} Bitwarden vault is locked."
        echo "Run: export BW_SESSION=\$(bw unlock --raw)"
        echo "Then run this script again."
        return 1
    fi

    echo "Restoring secrets from Bitwarden..."
    echo ""

    # SOPS age key
    if [[ -f "$sops_key" ]]; then
        echo -e "${GREEN}✓${NC} SOPS age key already exists (terraform/.sops-key)"
    else
        echo "  Fetching SOPS age key..."
        if bw get notes "homelab-sops-age-key" > "$sops_key" 2>/dev/null; then
            chmod 600 "$sops_key"
            echo -e "${GREEN}✓${NC} Restored SOPS age key to terraform/.sops-key"
        else
            echo -e "${RED}✗${NC} Could not find 'homelab-sops-age-key' in Bitwarden"
        fi
    fi

    # Ansible vault password
    if [[ -f "$vault_pass" ]]; then
        echo -e "${GREEN}✓${NC} Ansible vault password already exists (ansible/.vault_pass)"
    else
        echo "  Fetching Ansible vault password..."
        if bw get notes "homelab-ansible-vault-pass" > "$vault_pass" 2>/dev/null; then
            chmod 600 "$vault_pass"
            echo -e "${GREEN}✓${NC} Restored Ansible vault password to ansible/.vault_pass"
        else
            echo -e "${RED}✗${NC} Could not find 'homelab-ansible-vault-pass' in Bitwarden"
        fi
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Run 'direnv allow' to load environment variables"
    echo "  2. Verify with './scripts/setup-dev.sh --check'"
}

# Install tflint (optional, cross-platform)
install_tflint() {
    if check_cmd tflint; then
        echo "tflint already installed"
        return
    fi

    echo "Installing tflint..."
    curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
}

# Main installation
install_tools() {
    local os
    os=$(detect_os)

    echo "Detected OS: $os"
    echo ""

    case "$os" in
        arch)
            install_arch
            echo ""
            read -p "Install tflint (Terraform linter)? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                install_tflint
            fi
            ;;
        macos)
            install_macos
            ;;
        debian)
            echo -e "${YELLOW}Debian/Ubuntu detected but not fully supported yet.${NC}"
            echo "You can manually install:"
            echo "  sudo apt-get install shellcheck"
            echo "  pip install --user ansible-lint pre-commit yamllint"
            exit 1
            ;;
        *)
            echo -e "${RED}Error:${NC} Unsupported OS"
            echo "Supported: Arch Linux, macOS (Homebrew)"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${GREEN}Installation complete!${NC}"
    echo ""

    # Setup pre-commit hooks if config exists
    if [[ -f ".pre-commit-config.yaml" ]]; then
        echo "Setting up pre-commit hooks..."
        pre-commit install
        echo -e "${GREEN}✓${NC} Pre-commit hooks installed"
    else
        echo -e "${YELLOW}Note:${NC} No .pre-commit-config.yaml found"
        echo "Create one to enable automatic linting on commit"
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Add direnv hook to your shell profile (~/.bashrc or ~/.zshrc):"
    echo '     eval "$(direnv hook bash)"  # or zsh'
    echo "  2. Restore secrets from Bitwarden:"
    echo "     bw login && export BW_SESSION=\$(bw unlock --raw)"
    echo "     ./scripts/setup-dev.sh --setup-secrets"
    echo "  3. Allow direnv in this repo:"
    echo "     direnv allow"
    echo "  4. Verify with './scripts/setup-dev.sh --check'"
}

# Main
case "${1:-}" in
    --check|-c)
        check_tools
        ;;
    --setup-secrets|-s)
        setup_secrets
        ;;
    --help|-h)
        echo "Usage: $0 [--check|--setup-secrets|--help]"
        echo ""
        echo "Options:"
        echo "  --check, -c          Check current tool installation status"
        echo "  --setup-secrets, -s  Restore secrets from Bitwarden"
        echo "  --help, -h           Show this help message"
        echo ""
        echo "Without arguments, installs all development tools."
        ;;
    "")
        install_tools
        ;;
    *)
        echo "Unknown option: $1"
        echo "Run '$0 --help' for usage"
        exit 1
        ;;
esac
