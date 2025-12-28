{
  config,
  pkgs,
  inputs,
  ...
}:

let
  zjstatusPackage = inputs.zjstatus.packages.${pkgs.system}.default;
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

    # zjstatus permission grant helper layout
    # FIRST TIME SETUP: zjstatus needs permissions but the borderless status bar
    # hides the permission prompt. Run this once to grant permissions:
    #   zellij --layout ~/.config/zellij/layouts/grant-zjstatus-permissions.kdl
    # Navigate to top pane (Ctrl+p, k) and press 'y' to grant permissions.
    # Permissions persist in ~/.local/share/zellij/permissions.kdl
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

    # Layout generated with absolute plugin path (tilde doesn't expand in zellij)
    "zellij/layouts/default.kdl".text = ''
      layout {
          default_tab_template {
              // zjstatus bar at top
              pane size=1 borderless=true {
                  plugin location="file:${zjstatusPackage}/bin/zjstatus.wasm" {
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
    '';
  };

  home.packages = with pkgs; [
    # Core utilities
    ripgrep
    fd
    tree
    jq
    htop

    # Editor
    neovim

    # Git tools
    lazygit

    # Nix development
    nixfmt-rfc-style # Nix formatter (RFC standard)
    nil # Nix LSP

    # Session management
    zellij # Terminal multiplexer
    zesh # Session picker for zellij
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

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ]; # Replace cd with zoxide
    };
  };
}
