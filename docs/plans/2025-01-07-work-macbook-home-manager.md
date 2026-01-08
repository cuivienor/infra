# Work MacBook Home Manager Integration

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unify dotfiles management under Home Manager with a Shopify-specific profile for the work MacBook.

**Architecture:** Create a profile system under `home/profiles/shopify/` that extends the base user config with work-specific settings. The Shopify profile adds shell integrations (dev.sh, chruby, shadowenv), work git email, Claude proxy settings, and opencode work config. Activated via explicit flake output `cuiv@work-macbook`.

**Tech Stack:** Nix, Home Manager, flake.nix

---

## Phase 0: Migration Prep and Rollback Strategy

> **Important:** Complete this phase BEFORE any implementation. This ensures you can recover if something goes wrong.

### Task 0.1: Create Backup of Current Configuration

**Step 1: Create backup directory with timestamp**

```bash
BACKUP_DIR="$HOME/backup-before-hm-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "Backup directory: $BACKUP_DIR"
```

**Step 2: Backup all dotfiles and configs**

```bash
# Backup home dotfiles
cp -a ~/.zshrc ~/.zshenv ~/.gitconfig ~/.claude "$BACKUP_DIR/" 2>/dev/null || true

# Backup .config directory
cp -a ~/.config "$BACKUP_DIR/dot-config" 2>/dev/null || true

# Record what was backed up
ls -la "$BACKUP_DIR"
```

**Step 3: Note the backup location**

```bash
echo "$BACKUP_DIR" > ~/.hm-backup-location
echo "Backup location saved to ~/.hm-backup-location"
```

---

### Task 0.2: Audit Homebrew Packages for Removal

**Step 1: List Homebrew packages that HM will replace**

```bash
# These packages will be provided by Nix after HM activation
DUPLICATES="bat eza fd fzf htop jq lazygit neovim ripgrep starship tree zoxide"

echo "=== Packages to remove after HM activation ==="
for pkg in $DUPLICATES; do
  if brew list "$pkg" &>/dev/null; then
    echo "  - $pkg (installed)"
  fi
done
```

**Step 2: Save list for later reference**

```bash
brew list --formula > "$BACKUP_DIR/homebrew-formulas.txt"
brew list --cask > "$BACKUP_DIR/homebrew-casks.txt"
echo "Homebrew package lists saved to backup directory"
```

---

### Task 0.3: Unstow Current Dotfiles

**Step 1: Navigate to dotfiles repo**

```bash
cd ~/dotfiles
```

**Step 2: Dry-run unstow to see what will be removed**

```bash
./install-dotfiles.bash -n -d
```

Expected: Shows symlinks that will be removed

**Step 3: Actually unstow (remove symlinks)**

```bash
./install-dotfiles.bash -d
```

**Step 4: Verify symlinks are gone**

```bash
# These should no longer be symlinks
ls -la ~/.zshrc ~/.config/starship ~/.config/nvim 2>/dev/null
```

Expected: Files don't exist or are not symlinks

---

### Task 0.4: Document Rollback Procedure

**Rollback Option 1: Home Manager Generations (preferred)**

```bash
# List all HM generations
home-manager generations

# Rollback to previous generation
home-manager switch --rollback

# Or switch to specific generation
home-manager switch --generation <number>
```

**Rollback Option 2: Re-stow Original Configs**

```bash
# If HM completely breaks things, re-apply stow configs
cd ~/dotfiles
./install-dotfiles.bash -a macos
```

**Rollback Option 3: Manual Restore from Backup**

```bash
# Nuclear option - restore from backup
BACKUP_DIR=$(cat ~/.hm-backup-location)
cp -a "$BACKUP_DIR/.zshrc" ~/
cp -a "$BACKUP_DIR/.gitconfig" ~/
cp -a "$BACKUP_DIR/dot-config/"* ~/.config/
```

**Step 1: Save rollback instructions**

```bash
cat > "$BACKUP_DIR/ROLLBACK.md" << 'EOF'
# Rollback Instructions

## Option 1: HM Generations (preferred)
home-manager generations
home-manager switch --rollback

## Option 2: Re-stow
cd ~/dotfiles && ./install-dotfiles.bash -a macos

## Option 3: Manual restore
cp -a ~/.zshrc.backup ~/.zshrc
# etc.
EOF

echo "Rollback instructions saved to $BACKUP_DIR/ROLLBACK.md"
```

---

### Task 0.5: Verify Clean State

**Step 1: Confirm no stow symlinks remain for HM-managed paths**

```bash
# These paths should NOT be symlinks (HM will manage them)
for f in ~/.zshrc ~/.gitconfig ~/.config/starship ~/.config/zellij ~/.config/bat; do
  if [ -L "$f" ]; then
    echo "WARNING: $f is still a symlink!"
  else
    echo "OK: $f is not a symlink (or doesn't exist)"
  fi
done
```

**Step 2: Commit any changes to dotfiles repo**

```bash
cd ~/dotfiles
git status
# If there are changes, commit them
git add -A && git commit -m "chore: state before HM migration" || true
```

**Step 3: Ready for Phase 1**

Once all checks pass, proceed to Phase 1.

---

## Phase 1: Create Profile Directory Structure

### Task 1: Create Shopify Profile Directory

**Files:**
- Create: `home/profiles/shopify/default.nix`

**Step 1: Create the profiles directory and default.nix**

```nix
# home/profiles/shopify/default.nix
{ config, pkgs, lib, ... }:

{
  # Shopify work profile
  # Imports all Shopify-specific modules
  imports = [
    ./shell.nix
    ./git.nix
    ./claude.nix
    ../../users/cuiv/opencode/work.nix
  ];
}
```

**Step 2: Verify file created**

Run: `cat home/profiles/shopify/default.nix`
Expected: Contents match above

**Step 3: Commit**

```bash
git add home/profiles/shopify/default.nix
git commit -m "feat(home): add Shopify profile directory structure"
```

---

### Task 2: Create Shopify Shell Module

**Files:**
- Create: `home/profiles/shopify/shell.nix`

**Step 1: Create shell.nix with Shopify integrations**

```nix
# home/profiles/shopify/shell.nix
{ config, pkgs, lib, ... }:

{
  programs.zsh.initContent = lib.mkAfter ''
    # ===========================================
    # Shopify Work Environment
    # ===========================================

    # Shopify dev tool
    [ -f /opt/dev/dev.sh ] && source /opt/dev/dev.sh

    # Homebrew (for casks and work-specific tools)
    [[ -x /opt/homebrew/bin/brew ]] && eval $(/opt/homebrew/bin/brew shellenv)

    # chruby for Ruby version management (lazy-loaded)
    [[ -f /opt/dev/sh/chruby/chruby.sh ]] && { type chruby >/dev/null 2>&1 || chruby () { source /opt/dev/sh/chruby/chruby.sh; chruby "$@"; } }

    # tec agent initialization
    [[ -x /Users/cuiv/.local/state/tec/profiles/base/current/global/init ]] && eval "$(/Users/cuiv/.local/state/tec/profiles/base/current/global/init zsh)"

    # shadowenv for per-directory environments (must come after PATH modifications)
    if command -v shadowenv &> /dev/null; then
      eval "$(shadowenv init zsh)"
    fi
  '';
}
```

**Step 2: Verify file created**

Run: `cat home/profiles/shopify/shell.nix`
Expected: Contents match above

**Step 3: Commit**

```bash
git add home/profiles/shopify/shell.nix
git commit -m "feat(home): add Shopify shell integrations (dev, chruby, shadowenv)"
```

---

### Task 3: Create Shopify Git Module

**Files:**
- Create: `home/profiles/shopify/git.nix`

**Step 1: Create git.nix with work email and Shopify config include**

```nix
# home/profiles/shopify/git.nix
{ config, pkgs, lib, ... }:

{
  programs.git = {
    # Override email for work
    settings.user.email = lib.mkForce "peter.petrov@shopify.com";

    # Include Shopify's dev gitconfig
    includes = [
      { path = "~/.config/dev/gitconfig"; }
    ];
  };
}
```

**Step 2: Verify file created**

Run: `cat home/profiles/shopify/git.nix`
Expected: Contents match above

**Step 3: Commit**

```bash
git add home/profiles/shopify/git.nix
git commit -m "feat(home): add Shopify git config (work email, dev gitconfig include)"
```

---

### Task 4: Create Shopify Claude Module

**Files:**
- Create: `home/profiles/shopify/claude.nix`

**Step 1: Create claude.nix with settings.local.json for Shopify proxy**

```nix
# home/profiles/shopify/claude.nix
{ config, pkgs, lib, ... }:

{
  # Shopify-specific Claude Code settings
  # Written to settings.local.json which Claude merges with settings.json
  home.file.".claude/settings.local.json".text = builtins.toJSON {
    # Shopify AI proxy configuration
    apiKeyHelper = ''if [ -n "$AI_PROXY_KEY" ]; then echo $AI_PROXY_KEY; else /opt/dev/bin/dev tools run llm-gateway print-token --key 2>/dev/null; fi'';

    env = {
      ANTHROPIC_BASE_URL = "https://proxy.shopify.ai/vendors/anthropic-claude-code";
      ANTHROPIC_AUTH_TOKEN = "";
    };

    # Default to opus model
    model = "opus";

    # Additional work-specific permissions
    permissions = {
      allow = [
        # Shopify MCP tools
        "mcp__dev-mcp-from-shop-world__grokt_search"

        # Ruby/Rails development
        "Bash(bundle exec:*)"
        "Bash(bundle check:*)"
        "Bash(bundle install:*)"
        "Bash(bin/rails:*)"

        # Shopify dev tool
        "Bash(/opt/dev/bin/dev:*)"
      ];
    };
  };
}
```

**Step 2: Verify file created**

Run: `cat home/profiles/shopify/claude.nix`
Expected: Contents match above

**Step 3: Commit**

```bash
git add home/profiles/shopify/claude.nix
git commit -m "feat(home): add Shopify Claude config (proxy, work permissions)"
```

---

## Phase 2: Add Flake Output for Work MacBook

### Task 5: Add work-macbook homeConfiguration to flake.nix

**Files:**
- Modify: `flake.nix:188-210` (in homeConfigurations section)

**Step 1: Add the work-macbook configuration after existing aarch64-darwin config**

Find this section in flake.nix:
```nix
        "cuiv@aarch64-darwin" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "aarch64-darwin";
          modules = [
            ./home/users/cuiv/default.nix
            {
              home.username = "cuiv";
              home.homeDirectory = "/Users/cuiv";
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };
```

Add after it:
```nix
        # Work MacBook with Shopify profile
        "cuiv@work-macbook" = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "aarch64-darwin";
          modules = [
            ./home/users/cuiv/default.nix
            ./home/profiles/shopify/default.nix
            {
              home.username = "cuiv";
              home.homeDirectory = "/Users/cuiv";
            }
          ];
          extraSpecialArgs = { inherit inputs; };
        };
```

**Step 2: Verify the flake parses correctly**

Run: `nix flake check --no-build 2>&1 | head -20`
Expected: No syntax errors (warnings are OK)

**Step 3: Commit**

```bash
git add flake.nix
git commit -m "feat(home): add work-macbook flake output with Shopify profile"
```

---

## Phase 3: Add Tmux Fallback Module

### Task 6: Create Tmux Module for Fallback

**Files:**
- Create: `home/users/cuiv/tmux.nix`
- Modify: `home/users/cuiv/default.nix`

**Step 1: Create tmux.nix**

```nix
# home/users/cuiv/tmux.nix
{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;

    # Basic settings
    terminal = "tmux-256color";
    historyLimit = 10000;
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;

    # Use C-a as prefix (like screen)
    prefix = "C-a";

    extraConfig = ''
      # True color support
      set -ag terminal-overrides ",xterm-256color:RGB"

      # Vim-style pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Split panes with | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # New windows in current path
      bind c new-window -c "#{pane_current_path}"

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # Status bar - Catppuccin Mocha colors
      set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
      set -g status-left "#[fg=#1e1e2e,bg=#89b4fa,bold] #S "
      set -g status-right "#[fg=#cdd6f4] %Y-%m-%d %H:%M "
      set -g window-status-format "#[fg=#6c7086] #I:#W "
      set -g window-status-current-format "#[fg=#1e1e2e,bg=#a6e3a1,bold] #I:#W "
    '';
  };
}
```

**Step 2: Import tmux.nix in default.nix**

Edit `home/users/cuiv/default.nix` to add the import:

```nix
  imports = [
    ./git.nix
    ./tools.nix
    ./shell.nix
    ./neovim.nix
    ./claude.nix
    ./tmux.nix  # Add this line
  ];
```

**Step 3: Verify files**

Run: `cat home/users/cuiv/tmux.nix && grep tmux home/users/cuiv/default.nix`
Expected: tmux.nix contents and import line visible

**Step 4: Commit**

```bash
git add home/users/cuiv/tmux.nix home/users/cuiv/default.nix
git commit -m "feat(home): add tmux module as zellij fallback"
```

---

## Phase 4: Add t Script for Tmux Sessions

### Task 7: Add t Sessionizer Script

**Files:**
- Modify: `home/users/cuiv/tools.nix`

**Step 1: Add t script to xdg.configFile**

Add to `home/users/cuiv/tools.nix` inside the `xdg.configFile` block:

```nix
    # t sessionizer script for tmux (fallback from zellij)
    "scripts/t".source = pkgs.writeShellScript "t" ''
      #!/usr/bin/env bash
      # Tmux sessionizer - finds projects and creates/attaches to sessions

      # Project roots to search
      ROOTS=(
        "$HOME/dev"
        "$HOME/world/trees"
      )

      # Build find args
      FIND_ARGS=""
      for root in "''${ROOTS[@]}"; do
        if [[ -d "$root" ]]; then
          FIND_ARGS="$FIND_ARGS $root"
        fi
      done

      if [[ -z "$FIND_ARGS" ]]; then
        echo "No project roots found"
        exit 1
      fi

      # Select project with fzf
      if [[ $# -eq 1 ]]; then
        selected=$1
      else
        selected=$(find $FIND_ARGS -mindepth 1 -maxdepth 2 -type d 2>/dev/null | fzf)
      fi

      if [[ -z "$selected" ]]; then
        exit 0
      fi

      # Create session name from path
      selected_name=$(basename "$selected" | tr . _)
      tmux_running=$(pgrep tmux)

      # Create or attach to session
      if [[ -z $TMUX ]] && [[ -z "$tmux_running" ]]; then
        tmux new-session -s "$selected_name" -c "$selected"
        exit 0
      fi

      if ! tmux has-session -t="$selected_name" 2> /dev/null; then
        tmux new-session -ds "$selected_name" -c "$selected"
      fi

      tmux switch-client -t "$selected_name"
    '';
```

**Step 2: Add scripts directory to PATH in shell.nix**

Add to `home/users/cuiv/shell.nix` in the `initContent` block:

```nix
        # Add local scripts to PATH
        export PATH="$HOME/.config/scripts:$PATH"
```

**Step 3: Verify changes**

Run: `nix flake check --no-build 2>&1 | head -10`
Expected: No errors

**Step 4: Commit**

```bash
git add home/users/cuiv/tools.nix home/users/cuiv/shell.nix
git commit -m "feat(home): add t sessionizer script for tmux"
```

---

## Phase 5: Test and Activate

### Task 8: Build and Test Configuration

**Step 1: Build the work-macbook configuration without activating**

Run: `nix build .#homeConfigurations.cuiv@work-macbook.activationPackage --dry-run`
Expected: Shows what would be built, no errors

**Step 2: Actually build it**

Run: `nix build .#homeConfigurations.cuiv@work-macbook.activationPackage`
Expected: Build succeeds, creates `result` symlink

**Step 3: Commit any fixes if needed**

If there were build errors, fix them and commit:
```bash
git add -A
git commit -m "fix(home): address build errors in work-macbook config"
```

---

### Task 9: Document the Activation Process

**Files:**
- Modify: `home/CLAUDE.md`

**Step 1: Add work-macbook activation instructions to home/CLAUDE.md**

Add a new section:

```markdown
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
```

**Step 2: Commit**

```bash
git add home/CLAUDE.md
git commit -m "docs(home): add work-macbook activation instructions"
```

---

### Task 10: Create Personal Profile (Optional Symmetry)

**Files:**
- Create: `home/profiles/personal/default.nix`

**Step 1: Create personal profile for non-work machines**

```nix
# home/profiles/personal/default.nix
{ config, pkgs, lib, ... }:

{
  # Personal profile - for non-work machines
  # Currently just imports opencode personal config
  imports = [
    ../../users/cuiv/opencode/personal.nix
  ];
}
```

**Step 2: Update devbox NixOS config to use personal profile**

Edit `flake.nix` devbox section to explicitly use personal profile:

Find:
```nix
                users.cuiv = {
                  imports = [
                    ./home/users/cuiv/default.nix
                    ./home/users/cuiv/opencode/personal.nix
                  ];
                };
```

Replace with:
```nix
                users.cuiv = {
                  imports = [
                    ./home/users/cuiv/default.nix
                    ./home/profiles/personal/default.nix
                  ];
                };
```

**Step 3: Commit**

```bash
git add home/profiles/personal/default.nix flake.nix
git commit -m "feat(home): add personal profile, refactor devbox to use it"
```

---

## Phase 6: Final Verification

### Task 11: Full Build Test

**Step 1: Test all home configurations build**

Run in parallel:
```bash
nix build .#homeConfigurations.cuiv@work-macbook.activationPackage &
nix build .#homeConfigurations.cuiv@aarch64-darwin.activationPackage &
nix build .#homeConfigurations.cuiv@x86_64-linux.activationPackage &
wait
```

Expected: All three build successfully

**Step 2: Test devbox still builds**

Run: `nix build .#nixosConfigurations.devbox.config.system.build.toplevel --dry-run`
Expected: No errors

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(home): complete work-macbook Home Manager integration"
```

---

## Phase 7: Post-Activation Cleanup

> **Important:** Only proceed with this phase AFTER verifying HM activation works correctly.

### Task 12: Activate Home Manager

**Step 1: First-time HM activation**

```bash
cd ~/dev/infra
home-manager switch --flake .#cuiv@work-macbook
```

Expected: Activation completes, shell config updated

**Step 2: Restart shell**

```bash
exec zsh
```

**Step 3: Verify key tools work**

```bash
# Check Nix-provided tools are in PATH
which bat && bat --version
which eza && eza --version
which fzf && fzf --version
which nvim && nvim --version | head -1
which zellij && zellij --version

# Check shell config loaded
echo $EDITOR  # Should be nvim
starship --version
```

Expected: All tools available from Nix paths (`/nix/store/...`)

**Step 4: Verify Shopify integrations work**

```bash
# Check dev tool still works
type dev

# Check shadowenv
shadowenv --version

# Check git config
git config user.email  # Should be peter.petrov@shopify.com
```

---

### Task 13: Remove Duplicate Homebrew Packages

**Step 1: List packages to remove**

```bash
DUPLICATES="bat eza fd fzf htop jq lazygit neovim ripgrep starship tree zoxide shfmt shellcheck"

echo "=== Will uninstall these Homebrew packages ==="
for pkg in $DUPLICATES; do
  if brew list "$pkg" &>/dev/null; then
    echo "  brew uninstall $pkg"
  fi
done
```

**Step 2: Uninstall duplicates one at a time**

```bash
# Uninstall each, verifying Nix version works after each removal
for pkg in bat eza fd fzf htop jq lazygit neovim ripgrep starship tree zoxide; do
  if brew list "$pkg" &>/dev/null; then
    echo "Removing $pkg..."
    brew uninstall "$pkg"
    # Verify Nix version is now used
    which "$pkg"
  fi
done
```

**Step 3: Verify no conflicts remain**

```bash
# All should point to /nix/store/
which bat eza fd fzf htop jq lazygit nvim rg starship tree zoxide
```

---

### Task 14: Verify Rollback Works

**Step 1: Test generation listing**

```bash
home-manager generations
```

Expected: Shows at least one generation

**Step 2: Note current generation number**

```bash
home-manager generations | head -1
```

**Step 3: Document recovery command**

```bash
echo "To rollback: home-manager switch --rollback"
echo "To re-stow:  cd ~/dotfiles && ./install-dotfiles.bash -a macos"
```

---

## Summary

**Phases:**
- Phase 0: Migration prep (backup, audit, unstow, rollback docs)
- Phase 1-4: Create Shopify profile modules
- Phase 5: Add flake output
- Phase 6: Build and verify
- Phase 7: Activate and cleanup Homebrew

**Tasks:** 14 total (0.1-0.5 for prep, 1-11 for implementation, 12-14 for activation)

**New directory structure:**
```
home/
├── profiles/
│   ├── personal/
│   │   └── default.nix
│   └── shopify/
│       ├── default.nix
│       ├── shell.nix
│       ├── git.nix
│       └── claude.nix
└── users/cuiv/
    └── (existing + tmux.nix)
```

**New flake output:** `cuiv@work-macbook`

**Activation:** `home-manager switch --flake .#cuiv@work-macbook`

**Rollback options:**
1. `home-manager switch --rollback` (preferred)
2. `cd ~/dotfiles && ./install-dotfiles.bash -a macos` (re-stow)
3. Manual restore from `~/backup-before-hm-*`
