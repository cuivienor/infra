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

## ⌨️ Neovim Keybinding Strategy

The Neovim configuration follows a consistent keybinding strategy to minimize conflicts and maximize discoverability.

### Core Principles

1. **Leader-based organization**: Custom actions use `<leader>` (Space) for predictability
2. **Mnemonic prefixes**: First letter matches the action (d=diagnostics, s=search, etc.)
3. **Consistent namespacing**: Related actions grouped under same prefix
4. **No operator conflicts**: Never override Vim's core operators (d, c, y, etc.)
5. **Which-key integration**: All leader groups documented for discoverability

### Leader Key Namespaces

| Prefix | Purpose | Example Bindings |
|--------|---------|------------------|
| `<leader>c` | **C**ode / **C**opy | `ca` (code action), `cp` (copy path), `cf` (copy filename) |
| `<leader>d` | **D**iagnostics | `dd` (telescope), `dq` (quickfix), `de` (error float) |
| `<leader>D` | **D**ebug | `Dc` (continue), `Di` (step into), `Db` (breakpoint) |
| `<leader>f` | **F**ormat | `f` (format buffer), `fi` (format info) |
| `<leader>g` | **G**it/GitHub | `gh` (actions), `gp` (PRs), `gi` (issues) |
| `<leader>h` | Git **H**unks | `hs` (stage), `hr` (reset), `hp` (preview) |
| `<leader>i` | **I**con | `ii` (insert icon), `iy` (yank icon) |
| `<leader>m` | **M**isc | `mv` (move file) |
| `<leader>o` | **O**bsidian | `of` (follow link), `oc` (toggle checkbox) - markdown only |
| `<leader>r` | **R**ename | LSP rename (buffer-local) |
| `<leader>s` | **S**earch | `sf` (files), `sg` (grep), `sw` (word), `sh` (help) |
| `<leader>t` | **T**est | `tt` (this file), `ts` (nearest), `tl` (last), `ta` (all) |
| `<leader>T` | **T**oggle | `Tb` (git blame), `TD` (git deleted) |
| `<leader>w` | **W**orkspace | `ws*` (swap file management) |
| `<leader>x` | **X**codebuild | `xb` (build), `xr` (run), `xt` (test) - Swift projects only |
| `<leader><leader>` | Buffer list | Quick buffer switching |

### Non-Leader Bindings

**LSP Navigation (g-prefix)**
- `gd` - Goto definition (Telescope)
- `gr` - Goto references (Telescope)
- `gI` - Goto implementation (Telescope)
- `gt` - Goto type definition (Telescope)
- `gD` - Goto declaration
- `K` - Hover documentation

**Bracket Navigation**
- `[d` / `]d` - Previous/next diagnostic
- `[c` / `]c` - Previous/next git change
- `[x` / `]x` - Previous/next Xcode error

**Text Objects & Operators**
- `gc`, `gcc` - Comment.nvim (linewise)
- `gb`, `gbc` - Comment.nvim (blockwise)
- `sa`, `sd`, `sr` - Mini.surround (add, delete, replace)
- `-` - Oil.nvim (open parent directory)

**Control-based**
- `<C-h/j/k/l>` - Window navigation (tmux integration)
- `<C-p>` - Git files (Telescope)
- `<C-\>` - Toggle terminal (toggleterm)

### Adding New Keybindings

When adding new keybindings:

1. **Check for conflicts**: Use `:verbose map <key>` to check existing bindings
2. **Choose appropriate namespace**: Pick the most semantically correct leader prefix
3. **Update which-key**: Add group descriptions for new prefixes
4. **Document in config**: Add clear descriptions for all mappings
5. **Prefer leader keys**: Use `<leader>` for custom actions, leave g/[ shortcuts for built-ins

### Example

```lua
-- ✅ Good: Uses leader key with mnemonic prefix
vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "[C]ode [A]ction" })

-- ❌ Bad: Conflicts with Vim's delete operator
vim.keymap.set("n", "dc", dap.continue, { desc = "Debug Continue" })

-- ✅ Good: Uses leader with clear namespace
vim.keymap.set("n", "<leader>Dc", dap.continue, { desc = "[D]ebug [C]ontinue" })
```

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

## 🌐 Zine Development Setup

### Overview

The Neovim configuration includes full support for [Zine](https://zine-ssg.io/), a static site generator. This includes syntax highlighting, LSP support, and formatting for Ziggy, SuperMD, and SuperHTML.

### Initial Setup (One-time)

The following setup is required to enable Zine development support:

#### 1. Clone and Build Tools

```bash
# Clone repositories
cd ~/dev
git clone https://github.com/kristoff-it/ziggy.git
git clone https://github.com/kristoff-it/supermd.git
git clone https://github.com/kristoff-it/superhtml.git

# Build tools (requires Zig 0.15+)
cd ~/dev/ziggy && zig build --release=fast
cd ~/dev/supermd && zig build --release=fast
cd ~/dev/superhtml && zig build --release=fast

# Symlink binaries to PATH
ln -sf ~/dev/ziggy/zig-out/bin/ziggy ~/.local/bin/ziggy
ln -sf ~/dev/supermd/zig-out/bin/docgen ~/.local/bin/supermd
ln -sf ~/dev/superhtml/zig-out/bin/superhtml ~/.local/bin/superhtml
```

#### 2. Set up Treesitter Queries

```bash
# Create query directories
mkdir -p ~/.config/nvim/queries/{ziggy,ziggy_schema,supermd,supermd_inline,superhtml}

# Symlink query files
ln -sf ~/dev/ziggy/tree-sitter-ziggy/queries/* ~/.config/nvim/queries/ziggy/
ln -sf ~/dev/ziggy/tree-sitter-ziggy-schema/queries/* ~/.config/nvim/queries/ziggy_schema/
ln -sf ~/dev/supermd/editors/neovim/queries/supermd/* ~/.config/nvim/queries/supermd/
ln -sf ~/dev/supermd/editors/neovim/queries/supermd_inline/* ~/.config/nvim/queries/supermd_inline/
ln -sf ~/dev/superhtml/tree-sitter-superhtml/queries/* ~/.config/nvim/queries/superhtml/
```

#### 3. Install Treesitter Parsers

After the above setup, open Neovim and run:
```vim
:TSInstall ziggy ziggy_schema supermd supermd_inline superhtml
```

### Features

Once configured, you'll have:

- **File Type Detection**: Automatic detection for `.smd`, `.shtml`, `.ziggy`, and `.ziggy-schema` files
- **Syntax Highlighting**: Full Treesitter-based highlighting for all Zine languages
- **LSP Support**: 
  - Ziggy LSP for `.ziggy` files
  - Ziggy Schema LSP for `.ziggy-schema` files
  - SuperHTML LSP for `.shtml` and `.html` files
- **Formatting**: Format on save or with `<leader>f` for all Zine file types
- **Diagnostics**: Real-time error checking and validation

### Updating

To update the tools and parsers:
```bash
# Pull latest changes
cd ~/dev/ziggy && git pull && zig build --release=fast
cd ~/dev/supermd && git pull && zig build --release=fast
cd ~/dev/superhtml && git pull && zig build --release=fast

# Update parsers in Neovim
:TSUpdate ziggy ziggy_schema supermd supermd_inline superhtml
```

The configuration is managed in `stow/nvim/.config/nvim/lua/plugins/zine.lua`.
