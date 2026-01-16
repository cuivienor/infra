# Home Manager Zone

User environment via Home Manager + Nix. Modular config per concern.

## STRUCTURE

```
home/users/cuiv/
├── default.nix    # Entry point, imports all
├── git.nix        # Git config
├── shell.nix      # Zsh, starship, zoxide
├── tools.nix      # CLI tools (bat, fzf, eza)
└── zellij/        # Zellij KDL configs
    ├── config.kdl
    └── layouts/default.kdl
```

## ZELLIJ

**Theme:** Catppuccin Mocha (consistent everywhere)  
**Plugin:** zjstatus via flake input  
**Navigation:** `Ctrl+hjkl` (vim muscle memory)  
**Modes:** Native zellij, NOT tmux emulation

| Keys | Action |
|------|--------|
| `Ctrl+hjkl` | Pane navigation |
| `Ctrl+g` | Toggle locked |
| `Ctrl+p/t/s` | Pane/Tab/Scroll mode |

**Layout (4 tabs):** nvim → claude → git → scratch

**Source:** `home/users/cuiv/zellij/` (edit here, not `~/.config`)

## SHELL

- **Zsh** + oh-my-zsh
- **Starship** prompt (Catppuccin)
- **Zoxide:** `cd` aliased to `z`

## TOOLS

| Tool | Config |
|------|--------|
| bat | Catppuccin Mocha |
| fzf | Catppuccin, reverse layout |
| eza | Icons, git integration |
| zoxide | `--cmd cd` |

## SESSION MANAGER

**zesh** (`apps/zesh/`): Rust session manager
- Discovers projects in `~/dev`
- Frecency-based sorting
- Config: `~/.config/zesh/config.toml`

## APPLYING CHANGES

```bash
# On devbox
sudo nixos-rebuild switch --flake .#devbox

# Remote
nixos-rebuild switch --flake .#devbox --target-host devbox
```

## ADDING USER

1. Create `home/users/<username>/default.nix`
2. Import: git.nix, shell.nix, tools.nix
3. Reference in `nixos/hosts/<host>/configuration.nix`

## Work MacBook Setup

### First-Time Activation

```bash
# Install Home Manager if not present
nix run home-manager/release-25.11 -- init

# Activate work profile
home-manager switch --flake .#cuiv@work-macbook
```

### What the Shopify Profile Adds

- **Shell:** Sources dev.sh, Homebrew, chruby, shadowenv, tec
- **Git:** Work email (peter.petrov@shopify.com), includes dev/gitconfig
- **Claude:** Shopify proxy settings in settings.local.json
- **Opencode:** Work proxy with model mappings

### Switching Profiles

```bash
# Work MacBook (with Shopify profile)
home-manager switch --flake .#cuiv@work-macbook

# Personal macOS (without Shopify profile)
home-manager switch --flake .#cuiv@aarch64-darwin
```

### After Activation

1. Uninstall duplicate Homebrew packages (bat, eza, fzf, ripgrep, etc.)
2. Keep Homebrew for casks only (Raycast, gcloud-sdk, etc.)
3. Restart shell or run `exec zsh`
