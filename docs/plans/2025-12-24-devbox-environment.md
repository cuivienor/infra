# Devbox Development Environment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Peter's local dev environment to the devbox NixOS container using pure Home-Manager configuration.

**Architecture:** Modular Home-Manager configuration split into focused files (shell, editor, terminal, tools). Each module is self-contained and can be tested independently. Neovim uses a forked config with Nix-managed LSPs instead of Mason.

**Tech Stack:** NixOS 24.11, Home-Manager, Zsh, Neovim, Tmux, Starship, direnv

---

## Prerequisites

Before starting, ensure you can SSH to devbox:
```bash
ssh devbox  # Should connect to 192.168.1.140
```

All changes are made on your local machine and deployed via `nixos-rebuild`.

---

## Task 1: Create Modular Directory Structure

**Goal:** Convert flat `cuiv.nix` to modular directory structure.

**Files:**
- Rename: `home/users/cuiv.nix` → `home/users/cuiv/default.nix`
- Create: `home/users/cuiv/git.nix`
- Modify: `flake.nix:37`

### Step 1: Create the directory

```bash
mkdir -p home/users/cuiv
```

### Step 2: Move cuiv.nix to default.nix

```bash
mv home/users/cuiv.nix home/users/cuiv/default.nix
```

### Step 3: Create git.nix module

Create `home/users/cuiv/git.nix`:

```nix
{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Peter Petrov";
    userEmail = "peter@petrovs.io";

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;

      # Better diffs
      diff.algorithm = "histogram";

      # Useful aliases
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        lg = "log --oneline --graph --decorate";
      };
    };

    # Delta for better diffs (optional)
    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = false;
        line-numbers = true;
      };
    };
  };
}
```

**Nix Concept:** This is a *module* - a function that takes `{ config, pkgs, ... }` and returns an attribute set. The `...` means "ignore other arguments".

### Step 4: Update default.nix to import git.nix

Replace `home/users/cuiv/default.nix` with:

```nix
{ config, pkgs, ... }:

{
  # Import all modules
  imports = [
    ./git.nix
  ];

  # Home-Manager version - matches NixOS stateVersion
  home.stateVersion = "24.11";

  # Basic home configuration
  home.username = "cuiv";
  home.homeDirectory = "/home/cuiv";

  # Allow Home-Manager to manage itself
  programs.home-manager.enable = true;

  # Shell configuration (bash for now, will switch to zsh)
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
      l = "ls -CF";
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };

  # CLI tools (will move to tools.nix later)
  home.packages = with pkgs; [
    nixpkgs-fmt
    nil
    bat
    eza
    fzf
    zoxide
    delta  # For git delta
  ];

  # Direnv for automatic environment loading
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
    };
  };
}
```

**Nix Concept:** The `imports` list tells Nix to merge the contents of those files into this module. Order doesn't matter - Nix merges declaratively.

### Step 5: Verify the flake still works

```bash
nix flake check
```

Expected: No errors. The path `./home/users/cuiv.nix` still works because Nix automatically loads `default.nix` from a directory.

### Step 6: Deploy and verify

```bash
# From local machine, deploy to devbox
ssh devbox "cd /home/cuiv/dev/infra && git pull && sudo nixos-rebuild switch --flake .#devbox"
```

Or if you're working on devbox directly:
```bash
sudo nixos-rebuild switch --flake .#devbox
```

### Step 7: Verify git config on devbox

```bash
ssh devbox "git config --list | grep -E '(user|alias)'"
```

Expected output should include your git aliases and user info.

### Step 8: Commit

```bash
git add home/users/cuiv/
git commit -m "refactor: convert home-manager to modular structure

- Move cuiv.nix to cuiv/default.nix
- Extract git config to git.nix module
- Add git delta for better diffs"
```

---

## Task 2: Add CLI Tools Module

**Goal:** Create dedicated module for CLI tools with proper configuration.

**Files:**
- Create: `home/users/cuiv/tools.nix`
- Modify: `home/users/cuiv/default.nix`

### Step 1: Create tools.nix

Create `home/users/cuiv/tools.nix`:

```nix
{ config, pkgs, ... }:

{
  # CLI tools managed by Home-Manager
  home.packages = with pkgs; [
    # Core utilities
    ripgrep      # Better grep
    fd           # Better find
    tree         # Directory tree
    jq           # JSON processor
    htop         # Process viewer

    # Nix development
    nixpkgs-fmt  # Nix formatter
    nil          # Nix LSP
  ];

  # Bat - better cat with syntax highlighting
  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Mocha";
      style = "numbers,changes,header";
    };
    themes = {
      "Catppuccin Mocha" = {
        src = pkgs.fetchFromGitHub {
          owner = "catppuccin";
          repo = "bat";
          rev = "d714cc1d358ea51bfc02550f6b8f3c308e59c846";
          sha256 = "Q5B4NDrfCIK3UAMs94vdXnR42k4AXCqZz6sRn8bzmf4=";
        };
        file = "themes/Catppuccin Mocha.tmTheme";
      };
    };
  };

  # Eza - better ls
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
  };

  # Fzf - fuzzy finder
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
    ];
    # Catppuccin Mocha colors
    colors = {
      "bg+" = "#313244";
      "bg" = "#1e1e2e";
      "spinner" = "#f5e0dc";
      "hl" = "#f38ba8";
      "fg" = "#cdd6f4";
      "header" = "#f38ba8";
      "info" = "#cba6f7";
      "pointer" = "#f5e0dc";
      "marker" = "#f5e0dc";
      "fg+" = "#cdd6f4";
      "prompt" = "#cba6f7";
      "hl+" = "#f38ba8";
    };
  };

  # Zoxide - smarter cd
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];  # Replace cd with zoxide
  };
}
```

**Nix Concept:** `programs.<name>` are Home-Manager *modules* that configure specific programs. They handle installing the package AND generating config files. Using these is better than just adding to `home.packages` because they integrate properly with your shell.

### Step 2: Update default.nix to import tools.nix

Edit `home/users/cuiv/default.nix`, update imports and remove packages:

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./tools.nix
  ];

  home.stateVersion = "24.11";
  home.username = "cuiv";
  home.homeDirectory = "/home/cuiv";

  programs.home-manager.enable = true;

  # Shell configuration (bash for now)
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      la = "ls -A";
      l = "ls -CF";
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };

  # NOTE: home.packages moved to tools.nix

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
    };
  };
}
```

### Step 3: Rebuild and test

```bash
nix flake check
sudo nixos-rebuild switch --flake .#devbox
```

### Step 4: Verify tools work on devbox

```bash
ssh devbox
bat --version          # Should show bat with theme support
eza --version          # Should work
fzf --version          # Should work
zoxide --version       # Should work
cd /tmp && cd ~ && cd -  # Zoxide should remember paths
```

### Step 5: Commit

```bash
git add home/users/cuiv/tools.nix home/users/cuiv/default.nix
git commit -m "feat(devbox): add tools.nix with bat, eza, fzf, zoxide

- Configure bat with Catppuccin theme
- Configure eza with git integration and icons
- Configure fzf with Catppuccin colors
- Configure zoxide to replace cd"
```

---

## Task 3: Add Shell Configuration (Zsh)

**Goal:** Configure Zsh with native Home-Manager plugins (no Oh-My-Zsh).

**Files:**
- Create: `home/users/cuiv/shell.nix`
- Modify: `home/users/cuiv/default.nix`
- Modify: `nixos/hosts/devbox/configuration.nix`

### Step 1: Create shell.nix

Create `home/users/cuiv/shell.nix`:

```nix
{ config, pkgs, ... }:

{
  # Zsh configuration
  programs.zsh = {
    enable = true;

    # Enable built-in features
    enableCompletion = true;
    autosuggestion.enable = true;      # Fish-like suggestions
    syntaxHighlighting.enable = true;  # Syntax highlighting

    # Vi mode
    defaultKeymap = "viins";

    # History configuration
    history = {
      size = 10000;
      save = 10000;
      share = true;           # Share history between sessions
      ignoreDups = true;      # Don't save duplicates
      ignoreSpace = true;     # Don't save commands starting with space
      expireDuplicatesFirst = true;
    };

    # Shell aliases
    shellAliases = {
      # Modern replacements (eza, bat configured via programs.*)
      cat = "bat --paging=never";
      less = "bat --paging=always";
      grep = "rg";
      find = "fd";

      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # Git shortcuts
      g = "git";
      gs = "git status";
      gd = "git diff";
      ga = "git add";
      gc = "git commit";
      gp = "git pull";
      gl = "git lg";  # Uses our git alias

      # Quality of life
      c = "clear";
      h = "history";
      ports = "ss -tuln";

      # Safer operations
      rm = "rm -i";
      mv = "mv -i";
      cp = "cp -i";

      # Reload config
      reload = "source ~/.zshrc";
    };

    # Additional init commands
    initExtra = ''
      # Vi mode settings
      bindkey -v
      export KEYTIMEOUT=1

      # Arrow key history search
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward

      # Better word navigation
      bindkey '^[[1;5C' forward-word
      bindkey '^[[1;5D' backward-word

      # Edit command in $EDITOR with ctrl-e
      autoload -U edit-command-line
      zle -N edit-command-line
      bindkey '^e' edit-command-line

      # Case-insensitive completion
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

      # Completion colors
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
    '';

    # Environment variables
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    };
  };

  # Starship prompt with Catppuccin theme
  programs.starship = {
    enable = true;
    settings = {
      command_timeout = 10000;
      palette = "catppuccin_mocha";

      # Catppuccin Mocha palette
      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };
    };
  };

  # Direnv (already configured, but ensure zsh integration)
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };
}
```

**Nix Concept:** `programs.zsh.initExtra` is a string that gets appended to your `.zshrc`. The `''` syntax is a multi-line string in Nix. The `'''` inside escapes a literal `${` to prevent Nix interpolation.

### Step 2: Update default.nix

Edit `home/users/cuiv/default.nix`:

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./tools.nix
    ./shell.nix
  ];

  home.stateVersion = "24.11";
  home.username = "cuiv";
  home.homeDirectory = "/home/cuiv";

  programs.home-manager.enable = true;

  # NOTE: Bash kept as fallback, zsh is now primary
  programs.bash.enable = true;
}
```

### Step 3: Update NixOS config to set zsh as default shell

Edit `nixos/hosts/devbox/configuration.nix`, add zsh to system and set as user's shell:

```nix
{ config, pkgs, ... }:

{
  # ... existing config ...

  # Add zsh to system packages and /etc/shells
  programs.zsh.enable = true;

  # Users
  users.users = {
    root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeMlFdR2HiSqwxESTKFvgZB4OU/j+taT+dNv96V60Xd cuiv@laptop"
    ];

    cuiv = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;  # <-- ADD THIS LINE
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDeMlFdR2HiSqwxESTKFvgZB4OU/j+taT+dNv96V60Xd cuiv@laptop"
      ];
    };
  };

  # ... rest of config ...
}
```

### Step 4: Rebuild and test

```bash
nix flake check
sudo nixos-rebuild switch --flake .#devbox
```

### Step 5: Verify zsh is working

```bash
# Reconnect to get new shell
ssh devbox

# Should be in zsh now
echo $SHELL  # /run/current-system/sw/bin/zsh

# Test features
gs  # git status alias
..  # cd .. alias
# Type partial command, should see autosuggestions
# Arrow up/down should search history
```

### Step 6: Commit

```bash
git add home/users/cuiv/shell.nix home/users/cuiv/default.nix nixos/hosts/devbox/configuration.nix
git commit -m "feat(devbox): add zsh with native plugins and starship

- Configure zsh with autosuggestion, syntax highlighting, vi mode
- Add comprehensive shell aliases
- Configure starship with Catppuccin Mocha theme
- Set zsh as default shell for cuiv user"
```

---

## Task 4: Add Terminal Configuration (Tmux)

**Goal:** Configure tmux with Nix-managed plugins (no TPM).

**Files:**
- Create: `home/users/cuiv/terminal.nix`
- Modify: `home/users/cuiv/default.nix`

### Step 1: Create terminal.nix

Create `home/users/cuiv/terminal.nix`:

```nix
{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;

    # Prefix key: Ctrl+Space
    prefix = "C-Space";

    # Basic settings
    baseIndex = 1;           # Start windows at 1
    escapeTime = 0;          # No delay for escape
    historyLimit = 50000;    # Scrollback buffer
    keyMode = "vi";          # Vi-style bindings
    mouse = true;            # Enable mouse
    terminal = "tmux-256color";

    # Plugins (Nix-managed, no TPM needed)
    plugins = with pkgs.tmuxPlugins; [
      sensible           # Sensible defaults
      vim-tmux-navigator # Seamless vim/tmux navigation
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_window_current_text " #{window_name}"
          set -g @catppuccin_window_text " #{window_name}"
          set -g @catppuccin_status_left_separator "█"
          set -g @catppuccin_status_right_separator "█"
        '';
      }
    ];

    extraConfig = ''
      # True color support
      set-option -ga terminal-overrides ",xterm-256color:Tc"
      set -g allow-passthrough on

      # Status bar position
      set-option -g status-position top
      set -g status-right-length 100
      set -g status-left-length 100
      set -g status-left "#{E:@catppuccin_status_session}"
      set -g status-right "#{E:@catppuccin_status_application}"

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded..."

      # Split keybinds (more intuitive)
      unbind %
      bind s split-window -v -c "#{pane_current_path}"
      unbind '"'
      bind v split-window -h -c "#{pane_current_path}"

      # New window in current path
      bind c new-window -c "#{pane_current_path}"

      # Vi-style copy mode
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'

      # Pane navigation (vim-tmux-navigator handles this, but backup)
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Resize panes
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Session management
      bind-key -r t run-shell "tmux neww ~/.local/scripts/t"
    '';
  };

  # Clipboard support for tmux copy
  home.packages = with pkgs; [
    xclip
  ];
}
```

**Nix Concept:** `plugins` is a list that can contain either package names OR attribute sets with `plugin` and `extraConfig`. This lets you configure plugin-specific settings inline.

### Step 2: Update default.nix

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./tools.nix
    ./shell.nix
    ./terminal.nix
  ];

  home.stateVersion = "24.11";
  home.username = "cuiv";
  home.homeDirectory = "/home/cuiv";

  programs.home-manager.enable = true;
  programs.bash.enable = true;
}
```

### Step 3: Rebuild and test

```bash
nix flake check
sudo nixos-rebuild switch --flake .#devbox
```

### Step 4: Verify tmux works

```bash
ssh devbox
tmux new -s test

# Test keybinds:
# Ctrl+Space s  - horizontal split
# Ctrl+Space v  - vertical split
# Ctrl+h/j/k/l  - navigate panes (with vim-tmux-navigator)
# Ctrl+Space r  - reload config
# Ctrl+Space [  - enter copy mode (vi keys work)

tmux kill-session -t test
```

### Step 5: Commit

```bash
git add home/users/cuiv/terminal.nix home/users/cuiv/default.nix
git commit -m "feat(devbox): add tmux with catppuccin and vim-tmux-navigator

- Configure tmux with Ctrl+Space prefix
- Add Nix-managed plugins (sensible, catppuccin, vim-tmux-navigator)
- Configure vi-style copy mode with xclip integration
- Add intuitive split keybinds (s=horizontal, v=vertical)"
```

---

## Task 5: Add Custom Scripts

**Goal:** Add the tmux sessionizer script (`t`) and configure PATH.

**Files:**
- Create: `home/users/cuiv/scripts/t`
- Create: `home/users/cuiv/scripts.nix`
- Modify: `home/users/cuiv/default.nix`

### Step 1: Create scripts directory

```bash
mkdir -p home/users/cuiv/scripts
```

### Step 2: Create the sessionizer script

Create `home/users/cuiv/scripts/t`:

```bash
#!/usr/bin/env bash

# Tmux sessionizer - find and switch to project directories
# Inspired by ThePrimeagen's tmux-sessionizer

switch_to() {
    if [[ -z $TMUX ]]; then
        tmux attach-session -t "$1"
    else
        tmux switch-client -t "$1"
    fi
}

has_session() {
    tmux list-sessions 2>/dev/null | grep -q "^$1:"
}

tmux_init() {
    if [ -f "$2/.t" ]; then
        tmux send-keys -t "$1" "source $2/.t" c-M
    elif [ -f "$HOME/.t" ]; then
        tmux send-keys -t "$1" "source $HOME/.t" c-M
    fi
}

# Find project directories
find_projects() {
    {
        # Search in ~/dev for git repos (2 levels deep)
        [[ -d "$HOME/dev" ]] && fd -t d -d 2 -H '^\.git$' . "$HOME/dev" 2>/dev/null | while read -r git_dir; do
            echo "$(realpath "$(dirname "$git_dir")")"
        done

        # Search directly in home for git repos
        fd -t d -d 2 -H '^\.git$' . "$HOME" 2>/dev/null | while read -r git_dir; do
            echo "$(realpath "$(dirname "$git_dir")")"
        done

        # Search in src directories
        local src_dirs=("$HOME/src" "$HOME/dev/src")
        for src_dir in "${src_dirs[@]}"; do
            if [[ -d "$src_dir" ]]; then
                fd -t d -d 4 -H '^\.git$' . "$src_dir" 2>/dev/null | while read -r git_dir; do
                    project_dir=$(realpath "$(dirname "$git_dir")")
                    relative_path=${project_dir#$src_dir/}
                    depth=$(echo "$relative_path" | tr '/' '\n' | wc -l)
                    if [[ $depth -le 3 ]]; then
                        echo "$project_dir"
                    fi
                done
            fi
        done
    } | sort -u
}

# Main logic
if [[ $# -eq 1 ]]; then
    if [ -d "$1" ]; then
        selected=$(realpath "$1")
    else
        # Use zoxide for fuzzy matching
        selected=$(zoxide query "$1" 2>/dev/null || echo "")
    fi
else
    selected="$(find_projects | fzf --tmux=center)"
fi

if [[ -z $selected ]]; then
    exit 0
fi

selected_name=$(basename "$selected" | tr . _)
tmux_running=$(pgrep tmux)

if [[ -z $tmux_running ]] || ! has_session "$selected_name"; then
    tmux new-session -d -s "$selected_name" -c "$selected"
    tmux_init "$selected_name" "$selected"
fi

switch_to "$selected_name"
```

### Step 3: Create scripts.nix

Create `home/users/cuiv/scripts.nix`:

```nix
{ config, pkgs, ... }:

{
  # Add scripts directory to PATH
  home.sessionPath = [ "$HOME/.local/scripts" ];

  # Install scripts
  home.file.".local/scripts/t" = {
    source = ./scripts/t;
    executable = true;
  };

  # Ensure script dependencies are available
  home.packages = with pkgs; [
    # t script dependencies (fd, fzf, zoxide already in tools.nix)
    tmux
  ];
}
```

**Nix Concept:** `home.file` creates symlinks from the Nix store to your home directory. `source = ./scripts/t` references a file relative to THIS nix file. `executable = true` sets the execute bit.

### Step 4: Update default.nix

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./tools.nix
    ./shell.nix
    ./terminal.nix
    ./scripts.nix
  ];

  home.stateVersion = "24.11";
  home.username = "cuiv";
  home.homeDirectory = "/home/cuiv";

  programs.home-manager.enable = true;
  programs.bash.enable = true;
}
```

### Step 5: Rebuild and test

```bash
nix flake check
sudo nixos-rebuild switch --flake .#devbox
```

### Step 6: Verify script works

```bash
ssh devbox

# Check script is in PATH
which t  # Should show ~/.local/scripts/t

# Test the script (need some git repos first)
mkdir -p ~/dev/test-project
cd ~/dev/test-project
git init

# Now run t
t  # Should show fzf with test-project

# Or from tmux
tmux
# Ctrl+Space t  - should open fzf popup
```

### Step 7: Commit

```bash
git add home/users/cuiv/scripts/ home/users/cuiv/scripts.nix home/users/cuiv/default.nix
git commit -m "feat(devbox): add tmux sessionizer script

- Add 't' script for fuzzy project switching
- Configure PATH to include ~/.local/scripts
- Bind Ctrl+Space t in tmux to launch sessionizer"
```

---

## Task 6: Add Neovim Configuration (Editor)

**Goal:** Configure Neovim with Nix-managed LSPs (no Mason).

This is the most complex task. We'll:
1. Install Neovim and LSPs via Nix
2. Fork your nvim config to remove Mason
3. Configure via Home-Manager

**Files:**
- Create: `home/users/cuiv/editor.nix`
- Create: `home/users/cuiv/nvim/` (forked config)
- Modify: `home/users/cuiv/default.nix`

### Step 1: Create editor.nix with Neovim and LSPs

Create `home/users/cuiv/editor.nix`:

```nix
{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Neovim package with tree-sitter parsers
    package = pkgs.neovim-unwrapped;

    # Extra packages available to Neovim
    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server      # Lua
      nil                      # Nix
      nodePackages.bash-language-server  # Bash
      terraform-ls             # Terraform
      ansible-language-server  # Ansible
      pyright                  # Python types
      ruff                     # Python linting

      # Formatters
      stylua                   # Lua formatter
      nixpkgs-fmt              # Nix formatter
      shfmt                    # Shell formatter
      nodePackages.prettier    # Multi-language formatter

      # Linters
      shellcheck               # Shell linter
      ansible-lint             # Ansible linter
      yamllint                 # YAML linter

      # Tools for plugins
      ripgrep                  # Telescope dependency
      fd                       # Telescope dependency
      gcc                      # Treesitter compilation
      gnumake                  # Treesitter compilation
    ];
  };

  # Symlink nvim config from local directory
  xdg.configFile."nvim" = {
    source = ./nvim;
    recursive = true;
  };
}
```

**Nix Concept:** `extraPackages` makes these programs available on `$PATH` when running Neovim. This is how we provide LSPs to Neovim without Mason - they're just in PATH.

### Step 2: Copy and adapt your nvim config

```bash
# Copy your existing nvim config
cp -r dotfiles/stow/nvim/.config/nvim home/users/cuiv/nvim
```

### Step 3: Modify lsp.lua to remove Mason

Edit `home/users/cuiv/nvim/lua/plugins/lsp.lua`:

The key change is removing Mason and using LSPs from PATH. Here's the modified version:

```lua
return {
  "neovim/nvim-lspconfig",
  dependencies = {
    { "j-hui/fidget.nvim", opts = {} },
    { "folke/neodev.nvim", opts = {} },
  },
  config = function()
    -- Configure diagnostics display
    vim.diagnostic.config({
      virtual_text = true,
      signs = true,
      underline = true,
      update_in_insert = false,
      severity_sort = true,
      float = { source = "always" },
    })

    -- LSP keymaps on attach
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc)
          vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
        end

        map("gd", require("telescope.builtin").lsp_definitions, "Goto Definition")
        map("gr", require("telescope.builtin").lsp_references, "Goto References")
        map("gI", require("telescope.builtin").lsp_implementations, "Goto Implementation")
        map("gt", require("telescope.builtin").lsp_type_definitions, "Goto Type definition")
        map("<leader>ds", require("telescope.builtin").lsp_document_symbols, "Document Symbols")
        map("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Workspace Symbols")
        map("<leader>rn", vim.lsp.buf.rename, "Rename")
        map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
        map("K", vim.lsp.buf.hover, "Hover Documentation")
        map("gD", vim.lsp.buf.declaration, "Goto Declaration")

        -- Highlight references on cursor hold
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client.server_capabilities.documentHighlightProvider then
          local highlight_augroup = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
          vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })
        end

        -- Toggle inlay hints
        if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
          map("<leader>th", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
          end, "Toggle Inlay Hints")
        end
      end,
    })

    -- Create capabilities
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
    if has_cmp then
      capabilities = vim.tbl_deep_extend("force", capabilities, cmp_nvim_lsp.default_capabilities())
    end

    -- Server configurations
    -- These are all available via PATH from Nix (no Mason needed)
    local servers = {
      lua_ls = {
        settings = {
          Lua = {
            completion = { callSnippet = "Replace" },
            diagnostics = { disable = { "missing-fields" } },
          },
        },
      },
      nil_ls = {},  -- Nix LSP
      bashls = {},
      terraformls = { filetypes = { "tf", "terraform" } },
      ansiblels = {},
      pyright = {
        settings = {
          pyright = { disableOrganizeImports = true },
          python = { analysis = { ignore = { "*" } } },
        },
      },
      ruff = {},
    }

    -- Setup each server
    local lspconfig = require("lspconfig")
    for server_name, server_config in pairs(servers) do
      local config = vim.tbl_deep_extend("force", {
        capabilities = capabilities,
      }, server_config)
      lspconfig[server_name].setup(config)
    end
  end,
}
```

### Step 4: Remove Mason-related plugin files

Delete or comment out these files in your nvim config:
- `home/users/cuiv/nvim/lua/plugins/mason-null-ls.lua` (delete or empty)

Edit `mason-null-ls.lua` to be empty:
```lua
-- Mason removed - using Nix-managed LSPs
return {}
```

### Step 5: Update default.nix

```nix
{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./tools.nix
    ./shell.nix
    ./terminal.nix
    ./scripts.nix
    ./editor.nix
  ];

  home.stateVersion = "24.11";
  home.username = "cuiv";
  home.homeDirectory = "/home/cuiv";

  programs.home-manager.enable = true;
  programs.bash.enable = true;
}
```

### Step 6: Rebuild and test

```bash
nix flake check
sudo nixos-rebuild switch --flake .#devbox
```

### Step 7: Verify Neovim works

```bash
ssh devbox
nvim

# Check LSPs are available
:LspInfo  # Should show configured servers

# Test on a Lua file
nvim /tmp/test.lua
# Type some code, should see completion

# Test on a Nix file
nvim /tmp/test.nix
# Should have nil_ls attached
```

### Step 8: Commit

```bash
git add home/users/cuiv/editor.nix home/users/cuiv/nvim/
git commit -m "feat(devbox): add neovim with nix-managed LSPs

- Configure neovim via Home-Manager
- Install LSPs via Nix extraPackages (no Mason)
- Fork nvim config with Mason removed
- Include lua, nix, bash, terraform, ansible, python LSPs"
```

---

## Task 7: Final Verification and Cleanup

**Goal:** Verify everything works together and clean up.

### Step 1: Full rebuild

```bash
sudo nixos-rebuild switch --flake .#devbox
```

### Step 2: Test complete workflow

```bash
ssh devbox

# Verify shell
echo $SHELL               # /run/current-system/sw/bin/zsh
type gs                   # alias
type cat                  # bat alias

# Verify tools
bat --version
eza -la
fzf --version
zoxide query --list

# Verify tmux
tmux new -s test
# Ctrl+Space v - split
# Ctrl+Space t - sessionizer
# Ctrl+Space [ - copy mode

# Verify neovim
nvim
:checkhealth              # Check for errors
:LspInfo                  # Verify LSPs
:Telescope find_files    # Should work

# Exit tmux
tmux kill-server
```

### Step 3: Create verification checklist

Create `home/users/cuiv/README.md`:

```markdown
# Devbox Home-Manager Configuration

## Modules

| Module | Purpose |
|--------|---------|
| `default.nix` | Main entry, imports all modules |
| `git.nix` | Git configuration with delta |
| `tools.nix` | CLI tools (bat, eza, fzf, zoxide) |
| `shell.nix` | Zsh with plugins, starship prompt |
| `terminal.nix` | Tmux with catppuccin |
| `scripts.nix` | Custom scripts (t sessionizer) |
| `editor.nix` | Neovim with Nix-managed LSPs |

## Rebuilding

```bash
sudo nixos-rebuild switch --flake .#devbox
```

## Adding Packages

- System packages: `nixos/hosts/devbox/configuration.nix`
- User packages: `home/users/cuiv/tools.nix`
- LSPs: `home/users/cuiv/editor.nix` (extraPackages)

## Key Bindings

### Tmux (prefix: Ctrl+Space)
- `s` - Split horizontal
- `v` - Split vertical
- `t` - Sessionizer
- `r` - Reload config

### Neovim (leader: Space)
- `gd` - Go to definition
- `gr` - Go to references
- `K` - Hover docs
- `<leader>ca` - Code action
```

### Step 4: Final commit

```bash
git add home/users/cuiv/README.md
git add -A
git commit -m "docs(devbox): add home-manager configuration readme

Complete devbox environment setup with:
- Zsh with autosuggestion, syntax highlighting, vi mode
- Starship prompt with Catppuccin theme
- Tmux with vim-tmux-navigator
- Neovim with Nix-managed LSPs
- Custom scripts (tmux sessionizer)"
```

---

## Summary

You now have a fully declarative, reproducible development environment on devbox:

| Component | Status |
|-----------|--------|
| Shell (zsh) | Autosuggestions, syntax highlighting, vi mode |
| Prompt (starship) | Catppuccin Mocha theme |
| Terminal (tmux) | Catppuccin, vim-tmux-navigator |
| Editor (neovim) | Nix-managed LSPs, no Mason |
| Tools | bat, eza, fzf, zoxide with integrations |
| Scripts | Tmux sessionizer (`t`) |

**To add more:**
- New CLI tool → Add to `tools.nix`
- New LSP → Add to `editor.nix` extraPackages
- New shell alias → Add to `shell.nix`
- New tmux keybind → Add to `terminal.nix`

**To rebuild:**
```bash
sudo nixos-rebuild switch --flake .#devbox
```
