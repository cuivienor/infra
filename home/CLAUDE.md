# Home Manager Zone

User environment configuration managed via Home Manager and Nix.

## Structure

```
home/
├── profiles/           # Shared configuration profiles
└── users/
    └── cuiv/
        ├── default.nix # User entry point
        ├── git.nix     # Git configuration
        ├── shell.nix   # Zsh, starship, shell setup
        ├── tools.nix   # CLI tools (zellij, bat, fzf, etc.)
        └── zellij/     # Zellij KDL configs
            ├── config.kdl
            └── layouts/
                └── default.kdl
```

## Zellij Configuration

**Skill:** Use `cuiv-skills:zellij` for general zellij knowledge. Below are MY specific preferences.

### Design Decisions

See `docs/plans/2025-12-27-zellij-config-design.md` for full rationale.

**Key choices:**
- **Theme:** Catppuccin Mocha (consistent with all tools)
- **Status bar:** zjstatus plugin with custom Catppuccin formatting
- **Navigation:** `Ctrl+hjkl` for pane movement (vim muscle memory)
- **Modes:** Native zellij modes, NOT tmux prefix emulation
- **Layouts:** KDL files via `xdg.configFile`, not `programs.zellij`

### Keybindings

| Action | Keys | Notes |
|--------|------|-------|
| Pane navigation | `Ctrl+hjkl` | Custom, works in all modes except locked |
| Toggle locked | `Ctrl+g` | Default |
| Pane mode | `Ctrl+p` | Default |
| Tab mode | `Ctrl+t` | Default |
| Scroll mode | `Ctrl+s` | Default |

Trade-off: `Ctrl+l` no longer clears screen (use `clear` command).

### Default Layout

4-tab layout with zjstatus:
1. **nvim** - Editor (focus on start)
2. **claude** - Claude Code
3. **git** - Lazygit + shell pane
4. **scratch** - General shell

Commands run through `zsh -ic` for direnv/devshell support.

### Plugin Management

zjstatus is managed via flake input:
```nix
# flake.nix
inputs.zjstatus.url = "github:dj95/zjstatus";

# tools.nix
zjstatusPackage = inputs.zjstatus.packages.${pkgs.system}.default;
xdg.configFile."zellij/plugins/zjstatus.wasm".source = "${zjstatusPackage}/bin/zjstatus.wasm";
```

### Config Location

- **Source:** `home/users/cuiv/zellij/`
- **Deployed:** `~/.config/zellij/` (via Home Manager)
- **Edit source files**, not deployed files

## Shell Configuration

**File:** `shell.nix`

- Zsh with oh-my-zsh
- Starship prompt (Catppuccin)
- Zoxide for directory jumping (`cd` aliased to `z`)

## Tool Preferences

**File:** `tools.nix`

| Tool | Theme/Config |
|------|--------------|
| bat | Catppuccin Mocha |
| fzf | Catppuccin colors, reverse layout |
| eza | Icons, git integration |
| zoxide | `--cmd cd` (replaces cd) |

## Session Management

**zesh** is my custom session manager (Rust, in `apps/zesh/`):
- Discovers projects in `~/dev` (depth 2)
- Creates zellij sessions with project-specific or default layout
- Frecency-based sorting

Config: `~/.config/zesh/config.toml`

## Adding a New User

1. Create `home/users/<username>/default.nix`
2. Import modules: `git.nix`, `shell.nix`, `tools.nix`
3. Reference in `nixos/hosts/<host>/configuration.nix`

## Applying Changes

```bash
# On devbox
sudo nixos-rebuild switch --flake .#devbox

# Or remote
nixos-rebuild switch --flake .#devbox --target-host devbox
```

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
