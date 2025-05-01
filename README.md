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
