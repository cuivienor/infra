# Zellij Configuration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Set up zellij with catppuccin theme, zjstatus status bar, and custom layout matching existing tmux workflow.

**Architecture:** Add zjstatus as flake input, create KDL config files in `home/users/cuiv/zellij/`, wire up via Home Manager's `xdg.configFile`.

**Tech Stack:** Nix flakes, Home Manager, zellij (KDL config), zjstatus (WASM plugin)

---

## Task 1: Add zjstatus to flake inputs

**Files:**
- Modify: `flake.nix`

**Step 1: Add zjstatus input**

Add to the `inputs` section of `flake.nix`:

```nix
zjstatus = {
  url = "github:dj95/zjstatus";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

**Step 2: Pass zjstatus to Home Manager**

Update the `nixosConfigurations.devbox` module to pass zjstatus via `specialArgs`:

```nix
specialArgs = { inherit inputs; };
```

Then in the home-manager block, add:

```nix
home-manager = {
  useGlobalPkgs = true;
  useUserPackages = true;
  users.cuiv = import ./home/users/cuiv/default.nix;
  extraSpecialArgs = { inherit inputs; };
};
```

**Step 3: Update flake lock**

Run: `nix flake lock --update-input zjstatus`

**Step 4: Verify flake check passes**

Run: `nix flake check`
Expected: No errors

**Step 5: Commit**

```bash
git add flake.nix flake.lock
git commit -m "feat(nix): Add zjstatus flake input for zellij status bar"
```

---

## Task 2: Create zellij config directory structure

**Files:**
- Create: `home/users/cuiv/zellij/config.kdl`
- Create: `home/users/cuiv/zellij/layouts/default.kdl`

**Step 1: Create config directory**

```bash
mkdir -p home/users/cuiv/zellij/layouts
```

**Step 2: Create main config.kdl**

Create `home/users/cuiv/zellij/config.kdl`:

```kdl
// Zellij Configuration
// Managed by Home Manager - do not edit ~/.config/zellij/config.kdl directly

// Theme
theme "catppuccin-mocha"

// Core options
mouse_mode true
scroll_buffer_size 50000
copy_on_select true
copy_command "xclip -selection clipboard"
pane_frames false
default_layout "default"

// Keybindings
keybinds clear-defaults=false {
    // Pane navigation with Ctrl+hjkl (works in all modes except locked)
    shared_except "locked" {
        bind "Ctrl h" { MoveFocus "Left"; }
        bind "Ctrl j" { MoveFocus "Down"; }
        bind "Ctrl k" { MoveFocus "Up"; }
        bind "Ctrl l" { MoveFocus "Right"; }
    }
}
```

**Step 3: Create default layout**

Create `home/users/cuiv/zellij/layouts/default.kdl`:

```kdl
layout {
    default_tab_template {
        // zjstatus bar at top
        pane size=1 borderless=true {
            plugin location="file:~/.config/zellij/plugins/zjstatus.wasm" {
                format_left   "{mode} {tabs}"
                format_center ""
                format_right  "{session}"

                mode_normal  "#[bg=#a6e3a1,fg=#1e1e2e,bold] NORMAL "
                mode_locked  "#[bg=#6c7086,fg=#1e1e2e,bold] LOCKED "
                mode_pane    "#[bg=#89b4fa,fg=#1e1e2e,bold] PANE "
                mode_tab     "#[bg=#cba6f7,fg=#1e1e2e,bold] TAB "
                mode_scroll  "#[bg=#f9e2af,fg=#1e1e2e,bold] SCROLL "
                mode_resize  "#[bg=#f38ba8,fg=#1e1e2e,bold] RESIZE "

                tab_normal   "#[fg=#6c7086] {name} "
                tab_active   "#[fg=#fab387,bold] {name} "
            }
        }
        children
    }

    // Tab 1: Editor
    tab name="nvim" focus=true {
        pane command="nvim"
    }

    // Tab 2: Claude
    tab name="claude" {
        pane command="claude"
    }

    // Tab 3: Git (lazygit + shell)
    tab name="git" {
        pane split_direction="vertical" {
            pane command="lazygit"
            pane
        }
    }

    // Tab 4: Scratch
    tab name="scratch" {
        pane
    }
}
```

**Step 4: Commit**

```bash
git add home/users/cuiv/zellij/
git commit -m "feat(zellij): Add config and default layout files"
```

---

## Task 3: Wire up zellij config in Home Manager

**Files:**
- Modify: `home/users/cuiv/default.nix`
- Modify: `home/users/cuiv/tools.nix`

**Step 1: Update default.nix to accept inputs**

Modify `home/users/cuiv/default.nix` to accept and pass inputs:

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./git.nix
    ./tools.nix
    ./shell.nix
  ];

  # Pass inputs to imported modules
  _module.args = { inherit inputs; };

  # ... rest unchanged
}
```

**Step 2: Update tools.nix with zellij config**

Modify `home/users/cuiv/tools.nix`:

```nix
{ config, pkgs, inputs, ... }:

let
  zjstatusPackage = inputs.zjstatus.packages.${pkgs.system}.default;
in
{
  # Zesh session manager config
  xdg.configFile."zesh/config.toml".text = ''
    # Project discovery roots
    [[roots]]
    path = "~/dev"
    depth = 2
  '';

  # Zellij configuration
  xdg.configFile."zellij/config.kdl".source = ./zellij/config.kdl;
  xdg.configFile."zellij/layouts/default.kdl".source = ./zellij/layouts/default.kdl;
  xdg.configFile."zellij/plugins/zjstatus.wasm".source = "${zjstatusPackage}/bin/zjstatus.wasm";

  home.packages = with pkgs; [
    # Core utilities
    ripgrep
    fd
    tree
    jq
    htop

    # Nix development
    nixfmt-rfc-style
    nil

    # Session management
    zellij
    zesh
  ];

  # ... rest unchanged (programs block)
}
```

**Step 3: Verify nix flake check**

Run: `nix flake check`
Expected: No errors

**Step 4: Commit**

```bash
git add home/users/cuiv/default.nix home/users/cuiv/tools.nix
git commit -m "feat(zellij): Wire up config files via Home Manager"
```

---

## Task 4: Test the configuration

**Step 1: Build the NixOS configuration**

Run: `nix build .#nixosConfigurations.devbox.config.system.build.toplevel`
Expected: Build succeeds

**Step 2: Push and deploy to devbox**

```bash
git push origin feat/zesh-setup
```

On devbox:
```bash
cd ~/dev/infra
git pull
sudo nixos-rebuild switch --flake .#devbox
```

**Step 3: Verify zellij config is in place**

On devbox:
```bash
ls -la ~/.config/zellij/
cat ~/.config/zellij/config.kdl
ls -la ~/.config/zellij/plugins/
```

Expected: config.kdl, layouts/default.kdl, and plugins/zjstatus.wasm exist

**Step 4: Test zellij launches with layout**

Run: `zellij`
Expected:
- Opens with 4 tabs (nvim, claude, git, scratch)
- zjstatus bar visible at top with catppuccin colors
- Ctrl+hjkl navigates between panes

**Step 5: Test zesh integration**

Run: `zesh`
Expected: Picker appears, selecting a project opens zellij session

**Step 6: Commit any fixes if needed**

```bash
git add -A
git commit -m "fix(zellij): Adjust config based on testing"
```

---

## Task 5: Update zesh to remove default layout flag

**Files:**
- Modify: `apps/zesh/src/zellij.rs`

**Step 1: Check if zesh needs changes**

Currently zesh only adds `--new-session-with-layout` when a `.zellij.kdl` exists in the project. This is correct - zellij will use the `default_layout` from config.kdl when no layout is specified.

Verify this works: Run `zesh` and select a project without a `.zellij.kdl` file.

Expected: Session opens with the default 4-tab layout from `~/.config/zellij/layouts/default.kdl`.

**Step 2: If default layout not used, update zesh**

If zellij doesn't pick up the default layout, we may need to explicitly pass `--layout default` in zesh. Check behavior and fix if needed.

**Step 3: Commit if changes made**

```bash
git add apps/zesh/src/zellij.rs
git commit -m "fix(zesh): Ensure default layout is used for new sessions"
```

---

## Verification Checklist

After implementation, verify:

- [ ] `nix flake check` passes
- [ ] Zellij config files deployed to `~/.config/zellij/`
- [ ] zjstatus.wasm plugin present in plugins directory
- [ ] `zellij` launches with 4-tab layout
- [ ] zjstatus shows mode indicator and tabs
- [ ] `Ctrl+hjkl` navigates panes
- [ ] `Ctrl+g` toggles locked mode
- [ ] `Ctrl+s` enters scroll mode with vim keys
- [ ] Mouse selection copies to clipboard
- [ ] `zesh` creates sessions with correct layout
- [ ] Floating pane works (`Ctrl+p` → `w`)

---

## Future Enhancements (Not in Scope)

- Per-project `.zellij.kdl` layouts
- More zjstatus customization (git branch, datetime)
- Platform-specific copy_command (pbcopy for macOS)
- Shell integration for auto-renaming tabs
