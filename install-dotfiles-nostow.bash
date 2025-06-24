#!/usr/bin/env bash

# Pure bash implementation of GNU Stow functionality for dotfiles
# This script creates symbolic links from dotfiles to the home directory
# without requiring GNU Stow to be installed

set -euo pipefail

# Get location of script assuming it is in a dotfiles directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STOW_DIR="$BASE_DIR/stow"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage guide
usage() {
    echo "Usage: $0 [-n] [-d] [-f]"
    echo "-n    : Non-destructive (dry-run) mode, just display what would be done"
    echo "-d    : Unstow (delete) any symlinks managed by this repo"
    echo "-f    : Force mode, overwrite existing files/symlinks"
    exit 1
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to create a symlink
create_symlink() {
    local source="$1"
    local target="$2"
    local force="$3"
    
    # Create target directory if it doesn't exist
    local target_dir
    target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "Would create directory: $target_dir"
        else
            mkdir -p "$target_dir"
            log_info "Created directory: $target_dir"
        fi
    fi
    
    # Check if target already exists
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" ]]; then
            # It's a symlink
            local current_target
            current_target="$(readlink "$target")"
            if [[ "$current_target" == "$source" ]]; then
                log_info "Symlink already exists and points to correct target: $target"
                return 0
            else
                if [[ "$force" == "true" ]]; then
                    if [[ "$DRY_RUN" == "true" ]]; then
                        log_warning "Would overwrite existing symlink: $target -> $current_target"
                    else
                        rm "$target"
                        log_warning "Removed existing symlink: $target -> $current_target"
                    fi
                else
                    log_error "Symlink exists but points to different target: $target -> $current_target"
                    log_error "Use -f to force overwrite"
                    return 1
                fi
            fi
        else
            # It's a regular file or directory
            if [[ "$force" == "true" ]]; then
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_warning "Would overwrite existing file/directory: $target"
                else
                    rm -rf "$target"
                    log_warning "Removed existing file/directory: $target"
                fi
            else
                log_error "File/directory already exists: $target"
                log_error "Use -f to force overwrite"
                return 1
            fi
        fi
    fi
    
    # Create the symlink
    if [[ "$DRY_RUN" == "true" ]]; then
        log_success "Would create symlink: $target -> $source"
    else
        ln -s "$source" "$target"
        log_success "Created symlink: $target -> $source"
    fi
    
    return 0
}

# Function to remove a symlink
remove_symlink() {
    local target="$1"
    
    if [[ -L "$target" ]]; then
        local current_target
        current_target="$(readlink "$target")"
        # Check if this symlink points to our stow directory
        if [[ "$current_target" == "$STOW_DIR"/* ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_success "Would remove symlink: $target -> $current_target"
            else
                rm "$target"
                log_success "Removed symlink: $target -> $current_target"
            fi
        else
            log_warning "Symlink exists but doesn't point to our stow directory: $target -> $current_target"
        fi
    elif [[ -e "$target" ]]; then
        log_warning "Target exists but is not a symlink: $target"
    else
        log_info "Target doesn't exist: $target"
    fi
}

# Function to process a directory recursively
process_directory() {
    local source_dir="$1"
    local target_base="$2"
    local module_name="$3"
    local operation="$4"  # "stow" or "unstow"
    local force="$5"
    
    # Find all files and directories in the source directory
    while IFS= read -r -d '' item; do
        # Get relative path from source_dir
        local relative_path="${item#$source_dir/}"
        local target_path="$target_base/$relative_path"
        
        if [[ -d "$item" ]]; then
            # It's a directory - we don't need to do anything special for directories
            # as they will be created when we create symlinks for files
            continue
        else
            # It's a file
            if [[ "$operation" == "stow" ]]; then
                create_symlink "$item" "$target_path" "$force"
            elif [[ "$operation" == "unstow" ]]; then
                remove_symlink "$target_path"
            fi
        fi
    done < <(find "$source_dir" -type f -print0)
}

# Function to stow a module
stow_module() {
    local module_path="$1"
    local module_name="$2"
    local force="$3"
    
    log_info "Processing module: $module_name"
    
    # Process each top-level item in the module
    while IFS= read -r -d '' item; do
        local item_name
        item_name="$(basename "$item")"
        local target_path="$HOME/$item_name"
        
        if [[ -d "$item" ]]; then
            # It's a directory - process recursively
            process_directory "$item" "$HOME/$item_name" "$module_name" "stow" "$force"
        else
            # It's a file - create direct symlink
            create_symlink "$item" "$target_path" "$force"
        fi
    done < <(find "$module_path" -maxdepth 1 -mindepth 1 -print0)
}

# Function to unstow a module
unstow_module() {
    local module_path="$1"
    local module_name="$2"
    
    log_info "Unstowing module: $module_name"
    
    # Process each top-level item in the module
    while IFS= read -r -d '' item; do
        local item_name
        item_name="$(basename "$item")"
        local target_path="$HOME/$item_name"
        
        if [[ -d "$item" ]]; then
            # It's a directory - process recursively
            process_directory "$item" "$HOME/$item_name" "$module_name" "unstow" "false"
        else
            # It's a file - remove direct symlink
            remove_symlink "$target_path"
        fi
    done < <(find "$module_path" -maxdepth 1 -mindepth 1 -print0)
}

# Set default behavior
DRY_RUN="false"
DELETE="false"
FORCE="false"

# Parse command-line options
while getopts "ndf" option; do
    case $option in
    n) DRY_RUN="true" ;;
    d) DELETE="true" ;;
    f) FORCE="true" ;;
    *) usage ;;
    esac
done

# Remove parsed options from positional parameters
shift $((OPTIND - 1))

# Ensuring the base directory exists
if [[ ! -d "$STOW_DIR" ]]; then
    log_error "Stow directory $STOW_DIR does not exist."
    exit 1
fi

# Display what we're going to do
if [[ "$DRY_RUN" == "true" ]]; then
    log_info "DRY RUN MODE - No actual changes will be made"
fi

if [[ "$DELETE" == "true" ]]; then
    log_info "UNSTOW MODE - Removing symlinks"
else
    log_info "STOW MODE - Creating symlinks"
    if [[ "$FORCE" == "true" ]]; then
        log_warning "FORCE MODE - Will overwrite existing files"
    fi
fi

echo

# Loop over each directory inside the stow directory
for module_dir in "$STOW_DIR"/*/; do
    if [[ ! -d "$module_dir" ]]; then
        continue
    fi
    
    module_name="$(basename "$module_dir")"
    
    if [[ "$DELETE" == "true" ]]; then
        unstow_module "$module_dir" "$module_name"
    else
        stow_module "$module_dir" "$module_name" "$FORCE"
    fi
    
    echo
done

if [[ "$DRY_RUN" == "true" ]]; then
    echo
    log_info "Dry run completed. Run without -n to apply changes."
else
    echo
    log_success "Operation completed successfully!" 