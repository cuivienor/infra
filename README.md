# ✨ Personal dotfiles ✨

![neovim](https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white)
![tmux](https://img.shields.io/badge/tmux-1BB91F?style=for-the-badge&logo=tmux&logoColor=white)
![starship](https://img.shields.io/badge/starship-DD0B78?style=for-the-badge&logo=starship&logoColor=white)
![ZSH](https://img.shields.io/badge/Zsh-F15A24?style=for-the-badge&logo=Zsh&logoColor=white)

A collection of personal configuration files managed using GNU Stow.

## 🚀 Installation

```bash
# Install all modules
./install-dotfiles.bash

# Dry run to preview changes
./install-dotfiles.bash -n

# Remove all symlinks
./install-dotfiles.bash -d
```

## 🧩 Modules

- **X11** 🖥️ - X Window System configuration
- **config** ⚙️ - Core environment configuration and XDG paths
- **cspell** 📝 - Spell checking with custom dictionaries
- **ghostty** 👻 - Terminal emulator configuration
- **i3** 🪟 - Window manager with Catppuccin theme
- **npm** 📦 - Node.js package manager settings
- **nvim** 💻 - Neovim editor with plugins, LSP and tree-sitter
- **picom** 🔍 - X11 compositor for window effects
- **rofi** 🔎 - Application launcher with Catppuccin theme
- **screenlayout** 🖥️ - Display configuration scripts
- **scripts** 🛠️ - Utility scripts collection
  - `batl` 📜 - Pipe last command output to bat pager
  - `t` 📌 - Tmux integration helper
- **starship** 🚀 - Cross-shell prompt with Catppuccin theme
- **systemd** 🔄 - User services (ssh-agent)
- **tmux** 📊 - Terminal multiplexer configuration
- **zsh** 🐚 - Z-shell configuration with custom plugins and aliases

## 🎨 Theme

Most modules use the [Catppuccin](https://github.com/catppuccin/catppuccin) color scheme (primarily the Mocha variant).

## 🛍️ Shopify Development

### Neovim LSP Configuration for Shadowenv

The Neovim configuration includes specialized support for Shopify's `shadowenv` (Nix-based environment manager) to ensure proper LSP functionality across multiple Ruby projects with different versions and dependencies.

#### Architecture

**Core Module**: `stow/nvim/.config/nvim/lua/plugins/shadowenv.lua`

This module provides:
- Automatic detection of shadowenv projects (via `.shadowenv.d` directory)
- Per-project LSP instances with isolated environments
- Integration with project-specific Ruby, RuboCop, and Sorbet versions

#### How It Works

1. **Environment Loading**: When opening a Ruby file, the module:
   - Detects the project root
   - Loads the shadowenv environment for that project
   - Extracts Ruby paths from the Nix environment

2. **LSP Management**: Creates project-specific LSP instances:
   - `ruby_lsp_<project>` - Uses shadowenv's ruby-lsp
   - `rubocop_lsp_<project>` - Uses project's `bin/rubocop` (includes custom cops)
   - `sorbet_lsp_<project>` - Uses shadowenv's srb (if `sorbet/config` exists)

3. **Smart Formatting**: 
   - Diagnostics from LSP servers (real-time)
   - Formatting via conform.nvim with LSP preference (`lsp_format = "first"`)
   - Falls back to command-line formatters for non-shadowenv projects

#### Key Features

- **Project Isolation**: Each project uses its own Ruby version and gems
- **Custom Cops Support**: RuboCop automatically uses project-specific configurations
- **Zero Configuration**: Works automatically for any shadowenv project
- **Resource Management**: LSPs start/stop based on active buffers

#### Commands

- `:RubyShadowenvStatus` - Show status of Ruby/RuboCop/Sorbet LSP servers
- `:RubyShadowenvReload` - Restart LSP servers for current project
- `:RubyShadowenvDebug` - Debug shadowenv detection and configuration

This setup ensures that Neovim "just works" with Shopify's complex multi-project Ruby environment without manual configuration.
