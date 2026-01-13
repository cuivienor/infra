{
  config,
  pkgs,
  inputs,
  ...
}:

let
  zjstatusPackage = inputs.zjstatus.packages.${pkgs.stdenv.hostPlatform.system}.default;
  zellijSwitchWasm = pkgs.fetchurl {
    url = "https://github.com/mostafaqanbaryan/zellij-switch/releases/download/0.2.1/zellij-switch.wasm";
    sha256 = "sha256-7yV+Qf/rczN+0d6tMJlC0UZj0S2PWBcPDNq1BFsKIq4=";
  };
in
{
  # XDG config file management
  xdg.configFile = {
    # Zesh session manager config
    "zesh/config.toml".text = ''
      # Project discovery roots
      [[roots]]
      path = "~/dev"
      depth = 2
    '';

    # Zellij configuration
    "zellij/config.kdl".source = ./zellij/config.kdl;

    # zellij-switch plugin for in-session switching (used by zesh)
    "zellij/plugins/zellij-switch.wasm".source = zellijSwitchWasm;

    # zjstatus permission grant helper layout
    "zellij/layouts/grant-zjstatus-permissions.kdl".text = ''
      layout {
          pane size=3 {
              plugin location="file:${zjstatusPackage}/bin/zjstatus.wasm" {
                  format_left "{mode}"
                  format_right "{session}"
                  mode_normal "#[bold] NORMAL "
              }
          }
          pane
      }
    '';

    # Default layout with zjstatus Catppuccin theme
    # Uses replaceVars to inject zjstatus nix store path
    "zellij/layouts/default.kdl".source = pkgs.replaceVars ./zellij/layouts/default.kdl {
      zjstatus_path = "${zjstatusPackage}/bin/zjstatus.wasm";
    };

    # t sessionizer script for tmux (from apps/session-manager/t)
    "scripts/t".source = pkgs.writeShellScript "t" ''
      #!/usr/bin/env bash
      # Shamelessly lifted from prime https://github.com/ThePrimeagen/tmux-sessionizer
      # Tweaked using https://github.com/27medkamal/tmux-session-wizard/ as extra inspiration

      switch_to() {
        if [[ -z $TMUX ]]; then
          ${pkgs.tmux}/bin/tmux attach-session -t "$1"
        else
          ${pkgs.tmux}/bin/tmux switch-client -t "$1"
        fi
      }

      has_session() {
        ${pkgs.tmux}/bin/tmux list-sessions | ${pkgs.gnugrep}/bin/grep -q "^$1:"
      }

      tmux_init() {
        if [ -f "$2/.t" ]; then
          ${pkgs.tmux}/bin/tmux send-keys -t "$1" "source $2/.t" c-M
        elif [ -f "$HOME/.t" ]; then
          ${pkgs.tmux}/bin/tmux send-keys -t "$1" "source $HOME/.t" c-M
        fi
      }

      # Function to find project directories
      find_projects() {
        {
          # Hardcoded sparse checkout directory
          [[ -d "/Users/cuiv/world/trees/root/src/areas/core/shopify" ]] && echo "/Users/cuiv/world/trees/root/src/areas/core/shopify"

          # Shallow search in ~ and ~/dev (1 level deep, exclude hidden dirs)
          # Look for git repos at this level
          [[ -d "$HOME/dev" ]] && ${pkgs.fd}/bin/fd -t d -d 2 -H '^\.git$' . "$HOME/dev" 2>/dev/null | while read -r git_dir; do
            echo "$(realpath "$(dirname "$git_dir")")"
          done
          ${pkgs.fd}/bin/fd -t d -d 2 -H '^\.git$' . "$HOME" 2>/dev/null | while read -r git_dir; do
            echo "$(realpath "$(dirname "$git_dir")")"
          done

          # Search in src directories for git repositories at project level
          local src_dirs=("$HOME/src" "$HOME/dev/src" "$HOME/work/src")
          for src_dir in "''${src_dirs[@]}"; do
            if [[ -d "$src_dir" ]]; then
              # Find git repositories - limit depth to avoid going too deep into project subdirectories
              ${pkgs.fd}/bin/fd -t d -d 4 -H '^\.git$' . "$src_dir" 2>/dev/null | while read -r git_dir; do
                project_dir=$(realpath "$(dirname "$git_dir")")
                # Calculate depth from src_dir to ensure we only get top-level projects
                relative_path=''${project_dir#$src_dir/}
                depth=$(echo "$relative_path" | tr '/' '\n' | wc -l)
                # Only include projects at reasonable depth (1-3 levels: direct, org/repo, or host/org/repo)
                if [[ $depth -le 3 ]]; then
                  echo "$project_dir"
                fi
              done
            fi
          done
        } | sort -u
      }

      if [[ $# -eq 1 ]]; then
        if [ -d "$1" ]; then
          selected=$(realpath "$1")
        else
          selected=$(_ZO_FZF_OPTS="--tmux=center" ${pkgs.zoxide}/bin/zoxide query --interactive "$1")
        fi
      else
        selected="$(find_projects | sort -u | ${pkgs.fzf}/bin/fzf --tmux=center)"
      fi

      if [[ -z $selected ]]; then
        exit 0
      fi

      selected_name=$(basename "$selected" | tr . _)
      tmux_running=$(pgrep tmux)

      if [[ -z $tmux_running ]] || ! has_session "$selected_name"; then
        ${pkgs.tmux}/bin/tmux new-session -d -s "$selected_name" -c "$selected"
        tmux_init "$selected_name" "$selected"
      fi

      switch_to "$selected_name"
    '';
  };

  # Default tmux layout (sourced by t script when no project-specific .t exists)
  home.file.".t" = {
    text = ''
      #!/usr/bin/env bash

      # Window 1: nvim
      tmux send-keys "nvim ." c-M
      tmux rename-window "nvim"

      # Window 2: claude
      tmux new-window -n claude
      tmux send-keys "claude" c-M

      # Window 3: opencode
      tmux new-window -n opencode
      tmux send-keys "opencode" c-M

      # Window 4: git
      tmux new-window -n git
      tmux send-keys "lazygit" c-M

      # Window 5: scratch
      tmux new-window -n scratch

      # Window 9: servers
      tmux new-window -t 9 -n servers

      # Start in nvim window
      tmux select-window -t nvim
    '';
    executable = true;
  };

  home.packages = with pkgs; [
    ripgrep
    fd
    tree
    jq
    htop
    # neovim managed by nixCats in neovim.nix
    lazygit
    zellij
    zesh
    # Node.js for Claude Code
    nodejs_22
    # Note: openssl and dnsutils moved to devShell (infra-specific tools)
  ];

  programs = {
    bat = {
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
            rev = "6810349b28055dce54076712fc05fc68da4b8ec0";
            sha256 = "sha256-lJapSgRVENTrbmpVyn+UQabC9fpV1G1e+CdlJ090uvg=";
          };
          file = "themes/Catppuccin Mocha.tmTheme";
        };
      };
    };

    eza = {
      enable = true;
      enableZshIntegration = true;
      icons = "auto";
      git = true;
      extraOptions = [
        "--group-directories-first"
        "--header"
      ];
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [
        "--height 40%"
        "--layout=reverse"
        "--border"
      ];
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

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };

    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };
  };
}
