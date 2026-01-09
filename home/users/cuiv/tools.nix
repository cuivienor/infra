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
  };
}
