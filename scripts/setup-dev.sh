#!/bin/bash
# setup-dev.sh - Install development tools for homelab-notes repository
#
# Supports: Arch Linux, macOS (Homebrew)
# Installs: shellcheck, shfmt, yamllint, ansible-lint, pre-commit, tflint (optional)
#
# Usage:
#   ./scripts/setup-dev.sh           # Install all tools
#   ./scripts/setup-dev.sh --check   # Check what's installed

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
    
    # Note: ansible-lint and pre-commit available via brew on macOS
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
    echo "  1. Run './scripts/setup-dev.sh --check' to verify installation"
    echo "  2. Test linters manually:"
    echo "     shellcheck scripts/**/*.sh"
    echo "     yamllint ansible/"
    echo "     ansible-lint ansible/playbooks/"
    echo "     terraform fmt -check -recursive terraform/"
}

# Main
case "${1:-}" in
    --check|-c)
        check_tools
        ;;
    --help|-h)
        echo "Usage: $0 [--check|--help]"
        echo ""
        echo "Options:"
        echo "  --check, -c   Check current tool installation status"
        echo "  --help, -h    Show this help message"
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
