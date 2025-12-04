#!/bin/bash
# setup-dev.sh - Install development tools for homelab-notes repository
#
# Supports: Arch Linux, macOS (Homebrew)
# Installs: shellcheck, shfmt, yamllint, ansible-lint, pre-commit, tflint (optional)
#           sops, age, bitwarden-cli (secrets management)
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

    echo ""
    echo "Secrets management:"
    print_status "sops"
    print_status "age"
    print_status "bw"

    if [[ -f "$HOME/.sops/keys.txt" ]]; then
        echo -e "  ${GREEN}✓${NC} SOPS age key configured"
    else
        echo -e "  ${YELLOW}!${NC} SOPS age key not found (~/.sops/keys.txt)"
    fi

    if [[ -n "${SOPS_AGE_KEY_FILE:-}" ]]; then
        echo -e "  ${GREEN}✓${NC} SOPS_AGE_KEY_FILE is set"
    else
        echo -e "  ${YELLOW}!${NC} SOPS_AGE_KEY_FILE not set in environment"
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
    sudo pacman -S --needed --noconfirm age sops

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
    brew install sops age bitwarden-cli

    # Note: ansible-lint and pre-commit available via brew on macOS
}

# Setup SOPS age key
setup_sops_key() {
    local key_dir="$HOME/.sops"
    local key_file="$key_dir/keys.txt"

    if [[ -f "$key_file" ]]; then
        echo -e "${GREEN}✓${NC} SOPS key already exists at $key_file"
        # Show public key for reference
        local pub_key
        pub_key=$(grep "public key:" "$key_file" | cut -d: -f2 | tr -d ' ')
        if [[ -n "$pub_key" ]]; then
            echo "  Public key: $pub_key"
        fi
        return 0
    fi

    echo "SOPS age key not found."
    echo ""
    echo "Options:"
    echo "  1. Generate new key (first-time setup)"
    echo "  2. Restore from Bitwarden (existing key)"
    echo "  3. Skip (configure manually later)"
    echo ""
    read -p "Choose [1/2/3]: " -n 1 -r
    echo

    case $REPLY in
        1)
            mkdir -p "$key_dir"
            age-keygen -o "$key_file" 2>&1
            chmod 600 "$key_file"
            echo -e "${GREEN}✓${NC} Generated new age key at $key_file"
            echo ""
            echo -e "${YELLOW}Important:${NC} Back up this key to Bitwarden!"
            echo "  1. Log in: bw login"
            echo "  2. Create secure note named 'homelab-sops-age-key'"
            echo "  3. Paste the contents of $key_file"
            echo ""
            # Show the public key for .sops.yaml
            local pub_key
            pub_key=$(grep "public key:" "$key_file" | cut -d: -f2 | tr -d ' ')
            echo "Public key for .sops.yaml:"
            echo "  $pub_key"
            ;;
        2)
            if ! check_cmd bw; then
                echo -e "${RED}Error:${NC} Bitwarden CLI not installed"
                echo "Install it first, then run this again."
                return 1
            fi
            # Check if logged in
            if ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
                echo "Bitwarden vault is locked. Unlocking..."
                echo "Run: export BW_SESSION=\$(bw unlock --raw)"
                echo "Then run this script again."
                return 1
            fi
            echo "Fetching key from Bitwarden..."
            mkdir -p "$key_dir"
            if bw get notes "homelab-sops-age-key" > "$key_file" 2>/dev/null; then
                chmod 600 "$key_file"
                echo -e "${GREEN}✓${NC} Restored key from Bitwarden to $key_file"
            else
                echo -e "${RED}Error:${NC} Could not find 'homelab-sops-age-key' in Bitwarden"
                echo "Make sure the secure note exists with that exact name."
                return 1
            fi
            ;;
        3)
            echo "Skipping SOPS key setup"
            echo "You can run './scripts/setup-dev.sh --setup-sops' later."
            ;;
        *)
            echo "Invalid choice. Skipping."
            ;;
    esac
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
    echo "  3. Add to your shell profile (~/.bashrc or ~/.zshrc):"
    echo '     export SOPS_AGE_KEY_FILE="$HOME/.sops/keys.txt"'
    echo "  4. Setup SOPS key: ./scripts/setup-dev.sh --setup-sops"
}

# Main
case "${1:-}" in
    --check|-c)
        check_tools
        ;;
    --setup-sops|-s)
        setup_sops_key
        ;;
    --help|-h)
        echo "Usage: $0 [--check|--setup-sops|--help]"
        echo ""
        echo "Options:"
        echo "  --check, -c       Check current tool installation status"
        echo "  --setup-sops, -s  Setup or restore SOPS age key"
        echo "  --help, -h        Show this help message"
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
