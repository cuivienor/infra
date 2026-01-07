# Dotfiles Zone

GNU Stow managed dotfiles. Catppuccin Mocha theme throughout.

## COMMANDS

```bash
./install-dotfiles.bash      # Install (auto-detect platform)
./install-dotfiles.bash -n   # Dry run
./install-dotfiles.bash -d   # Remove symlinks
./install-dotfiles.bash -a macos  # Specific architecture
```

## STRUCTURE

```
dotfiles/
├── stow/                    # All modules
│   ├── nvim/               # Neovim (lazy.nvim)
│   ├── tmux/               # Terminal multiplexer
│   ├── zsh/                # Shell config
│   ├── starship/           # Prompt
│   └── ...
├── install-dotfiles.bash   # Installer
└── dotfiles-config.json    # Architecture definitions
```

## KEY MODULES

| Module | Purpose |
|--------|---------|
| nvim | Neovim + lazy.nvim, LSP, treesitter |
| tmux | Catppuccin theme, vim-tmux-navigator |
| zsh | oh-my-zsh, plugins, aliases |
| starship | Cross-shell prompt |
| i3/rofi/picom | Linux desktop |
| aerospace | macOS tiling WM |

## UTILITIES

- **t** - Tmux sessionizer (in `stow/scripts/`)
- **batl** - Pipe last command to bat (re-executes!)

## ARCHITECTURES

| Name | Platforms |
|------|-----------|
| linux | Full Linux desktop |
| macos | macOS specific |
| corporate | Work environment |
| minimal | Servers, containers |

Auto-detected via `uname -s` and `CORPORATE_ENV`/`WORK_ENV`.

## ADDING MODULES

1. Create `stow/<module>/` with XDG paths
2. Add to `dotfiles-config.json`
3. Test: `./install-dotfiles.bash -n`

## SPECIAL FILES

- `.t` - Project tmux init (sourced by `t`)
- `dotfiles-config.json` - Package/arch definitions
