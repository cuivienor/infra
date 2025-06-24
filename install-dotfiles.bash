#!/usr/bin/env bash

# Get location of script assuming it is in a dotfiles directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$BASE_DIR/stow"
CONFIG_FILE="$BASE_DIR/dotfiles-config.json"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to parse JSON (requires jq or python)
parse_json() {
    local json_file="$1"
    local query="$2"
    
    if command_exists jq; then
        jq -r ".$query" "$json_file" 2>/dev/null
    elif command_exists python3; then
        python3 -c "
import json, sys
try:
    with open('$json_file', 'r') as f:
        data = json.load(f)
    result = data
    for key in '$query'.split('.'):
        if key.startswith('[') and key.endswith(']'):
            index = int(key[1:-1])
            result = result[index]
        elif key and key != '':
            result = result[key]
    if isinstance(result, list):
        for item in result:
            print(item)
    else:
        print(result)
except:
    sys.exit(1)
        " 2>/dev/null
    else
        echo "JSON parsing requires either 'jq' or 'python3' to be installed"
        return 1
    fi
}

# Function to get packages for architecture
get_packages_for_arch() {
    local arch="$1"
    local packages
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    packages=$(parse_json "$CONFIG_FILE" "architectures.$arch.packages[]")
    if [[ $? -ne 0 || -z "$packages" ]]; then
        echo "Failed to get packages for architecture: $arch"
        return 1
    fi
    
    echo "$packages"
}

# Function to detect architecture automatically
detect_architecture() {
    local os
    os=$(uname -s)
    
    case "$os" in
        Linux*)
            if [[ -n "${CORPORATE_ENV:-}" ]] || [[ -n "${WORK_ENV:-}" ]]; then
                echo "corporate"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            if [[ -n "${CORPORATE_ENV:-}" ]] || [[ -n "${WORK_ENV:-}" ]]; then
                echo "corporate"
            else
                echo "macos"
            fi
            ;;
        *)
            echo "minimal"
            ;;
    esac
}

# Function to list available architectures
list_architectures() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    echo "Available architectures:"
    echo
    
    local archs
    if command_exists jq; then
        archs=$(jq -r '.architectures | keys[]' "$CONFIG_FILE" 2>/dev/null)
    elif command_exists python3; then
        archs=$(python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    data = json.load(f)
for arch in data['architectures'].keys():
    print(arch)
        " 2>/dev/null)
    else
        echo "JSON parsing requires either 'jq' or 'python3' to be installed"
        return 1
    fi
    
    for arch in $archs; do
        local desc
        desc=$(parse_json "$CONFIG_FILE" "architectures.$arch.description")
        local packages
        packages=$(parse_json "$CONFIG_FILE" "architectures.$arch.packages[]" | wc -l)
        printf "  %-12s - %s (%s packages)\n" "$arch" "$desc" "$packages"
    done
}

# If GNU Stow is installed
if ! command -v stow &>/dev/null; then
    echo "GNU Stow could not be found. Please install it first."
    exit 1
fi

# Function to display usage guide
usage() {
    echo "Usage: $0 [-n] [-d] [-a ARCH] [-l]"
    echo "-n    : Non-destructive (dry-run) mode, just display what would be done"
    echo "-d    : Unstow (delete) any symlinks managed my this repo"
    echo "-a    : Target architecture (linux, macos, corporate, minimal)"
    echo "-l    : List available architectures and packages"
    exit 1
}

# Set default behavior
DRY_RUN="false"
ARCHITECTURE=""
LIST_ARCHITECTURES="false"

# Parse command-line options
while getopts "nda:l" option; do
    case $option in
    n) DRY_RUN="true" ;;
    d) DELETE="true" ;;
    a) ARCHITECTURE="$OPTARG" ;;
    l) LIST_ARCHITECTURES="true" ;;
    *) usage ;;
    esac
done

# Remove parsed options from positional parameters
shift $((OPTIND - 1))

# Handle list architectures option
if [[ "$LIST_ARCHITECTURES" == "true" ]]; then
    list_architectures
    exit 0
fi

# Ensuring the base directory exists
if [ ! -d "$STOW_DIR" ]; then
    echo "Stow directory $STOW_DIR does not exist."
    exit 1
fi

# Determine target architecture
if [[ -z "$ARCHITECTURE" ]]; then
    ARCHITECTURE=$(detect_architecture)
    echo "Auto-detected architecture: $ARCHITECTURE"
else
    echo "Using specified architecture: $ARCHITECTURE"
fi

# Validate architecture and get package list
PACKAGES_TO_INSTALL=$(get_packages_for_arch "$ARCHITECTURE")
if [[ $? -ne 0 ]]; then
    echo "Invalid architecture: $ARCHITECTURE"
    echo "Use -l to list available architectures"
    exit 1
fi

# Convert packages list to space-separated string for lookup
PACKAGE_LIST=" $(echo "$PACKAGES_TO_INSTALL" | tr '\n' ' ') "

echo "Packages to process for architecture '$ARCHITECTURE':"
printf "  %s\n" $PACKAGES_TO_INSTALL
echo

# Enter the base directory
cd "$STOW_DIR" || exit

# Loop over each directory inside the base directory and run stow
for module in */; do
    module_name="${module%/}" # Remove trailing slash
    
    # Check if this package should be installed for the current architecture
    if [[ "$PACKAGE_LIST" != *" $module_name "* ]]; then
        echo "Skipping $module_name (not included in $ARCHITECTURE architecture)"
        continue
    fi
    
    if [ "$DRY_RUN" == "true" ]; then
        if [ "$DELETE" == "true" ]; then
            echo "Dry-Run: Would run 'stow -t $HOME -D $module_name'"
            stow -nD "$module_name"
        else
            echo "Dry-Run: Would run 'stow -nv -t $HOME $module_name'"
            stow -nv "$module_name"
        fi
    else
        if [ "$DELETE" == "true" ]; then
            echo "Unstowing $module_name"
            stow -t "$HOME" -D "$module_name"
        else
            echo "Stowing $module_name..."
            stow -t "$HOME" -v "$module_name"
        fi
    fi
done
