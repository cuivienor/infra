# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository managed using GNU Stow. It contains configuration files for various tools and applications organized in a modular architecture that supports different platforms (Linux, macOS) and environments (corporate, minimal).

## Architecture

The repository uses a JSON-based configuration system (`dotfiles-config.json`) that defines:
- **Architectures**: Platform-specific package sets (linux, macos, corporate, minimal)
- **Package definitions**: Individual configuration modules with platform compatibility

### Structure
- `stow/` - Contains all dotfiles modules organized by application
- `install-dotfiles.bash` - Main installation script with architecture detection
- `dotfiles-config.json` - Architecture and package configuration

## Common Commands

### Installation and Management
```bash
# Install all modules for current platform (auto-detected)
./install-dotfiles.bash

# Dry run to preview changes
./install-dotfiles.bash -n

# Install specific architecture
./install-dotfiles.bash -a macos
./install-dotfiles.bash -a corporate

# Remove all symlinks
./install-dotfiles.bash -d

# List available architectures
./install-dotfiles.bash -l
```

### Key Utilities
- `t` - Tmux sessionizer script (located in `stow/scripts/.local/scripts/t`)
  - Finds and switches to project directories
  - Integrates with zoxide for fuzzy directory finding
  - Supports `.t` project initialization files
- `batl` - Pipe last command output to bat pager

## Key Configuration Files

### Core Components
- **nvim**: Neovim configuration using lazy.nvim plugin manager
- **tmux**: Terminal multiplexer with Catppuccin theme, vim-tmux-navigator
- **zsh**: Z-shell with oh-my-zsh, plugins, and custom configuration
- **starship**: Cross-shell prompt with Catppuccin theme

### Platform-Specific
- **i3/picom/rofi/X11**: Linux desktop environment components
- **aerospace**: macOS tiling window manager
- **systemd**: Linux user services

## Development Workflow

### Making Changes
1. Edit configuration files in appropriate `stow/[module]/` directory
2. Test changes with dry run: `./install-dotfiles.bash -n`
3. Apply changes: `./install-dotfiles.bash`

### Adding New Modules
1. Create new directory under `stow/`
2. Add module to `dotfiles-config.json` with platform compatibility
3. Update README.md modules section if needed

### Architecture Detection
The installation script automatically detects platform and environment:
- Linux vs macOS via `uname -s`
- Corporate environment via `CORPORATE_ENV` or `WORK_ENV` variables
- Falls back to minimal architecture for unknown platforms

## Special Files
- `.t` files: Project-specific tmux initialization scripts
- `$HOME/.env`: Source file for environment secrets (optional)
- `$XDG_CONFIG_HOME/path.bash`: PATH modifications