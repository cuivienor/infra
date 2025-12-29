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
    # Riced zjstatus with Catppuccin Mocha - based on merikan/.dotfiles style
    "zellij/layouts/default.kdl".text = ''
      layout {
          default_tab_template {
              // zjstatus bar at top
              pane size=1 borderless=true {
                  plugin location="file:${zjstatusPackage}/bin/zjstatus.wasm" {
                      // Catppuccin Mocha palette
                      color_base "#1e1e2e"
                      color_surface0 "#313244"
                      color_surface1 "#45475a"
                      color_text "#cdd6f4"
                      color_subtext1 "#bac2de"
                      color_crust "#11111b"
                      color_green "#a6e3a1"
                      color_peach "#fab387"
                      color_blue "#89b4fa"
                      color_sapphire "#74c7ec"
                      color_mauve "#cba6f7"
                      color_red "#f38ba8"
                      color_yellow "#f9e2af"
                      color_teal "#94e2d5"
                      color_flamingo "#f2cdcd"
                      color_pink "#f5c2e7"
                      color_overlay0 "#6c7086"

                      // Layout: [SESSION] [MODE] [TABS] ... [GIT] [USER@HOST] [TIME]
                      // Using explicit unicode escapes for powerline:  = ,  =
                      format_left   "#[bg=$surface0,fg=$sapphire]#[bg=$sapphire,fg=$crust,bold] {session} #[bg=$surface0,fg=$sapphire] {mode}#[bg=$surface0] {tabs}"
                      format_center ""
                      format_right  "#[bg=$surface0,fg=$blue]#[bg=$blue,fg=$crust] #[bg=$surface1,fg=$blue,bold] {command_git_branch}#[bg=$surface0,fg=$surface1]#[bg=$surface0,fg=$flamingo]#[bg=$flamingo,fg=$crust]󰉤 #[bg=$surface1,fg=$flamingo,bold] {command_user}@{command_host}#[bg=$surface0,fg=$surface1]#[bg=$surface0,fg=$overlay0]#[bg=$overlay0,fg=$crust]󰅐 #[bg=$surface1,fg=$overlay0,bold] {datetime}#[bg=$surface0,fg=$surface1]"
                      format_space  "#[bg=$surface0]"
                      format_hide_on_overlength "true"
                      format_precedence "lrc"

                      border_enabled  "false"
                      hide_frame_for_single_pane "true"

                      // Mode indicators
                      mode_normal        "#[bg=$green,fg=$crust,bold] NORMAL#[bg=$surface0,fg=$green]"
                      mode_tmux          "#[bg=$mauve,fg=$crust,bold] TMUX#[bg=$surface0,fg=$mauve]"
                      mode_locked        "#[bg=$red,fg=$crust,bold] LOCKED#[bg=$surface0,fg=$red]"
                      mode_pane          "#[bg=$teal,fg=$crust,bold] PANE#[bg=$surface0,fg=$teal]"
                      mode_tab           "#[bg=$teal,fg=$crust,bold] TAB#[bg=$surface0,fg=$teal]"
                      mode_scroll        "#[bg=$flamingo,fg=$crust,bold] SCROLL#[bg=$surface0,fg=$flamingo]"
                      mode_enter_search  "#[bg=$flamingo,fg=$crust,bold] SEARCH#[bg=$surface0,fg=$flamingo]"
                      mode_search        "#[bg=$flamingo,fg=$crust,bold] SEARCH#[bg=$surface0,fg=$flamingo]"
                      mode_resize        "#[bg=$yellow,fg=$crust,bold] RESIZE#[bg=$surface0,fg=$yellow]"
                      mode_rename_tab    "#[bg=$yellow,fg=$crust,bold] RENAME#[bg=$surface0,fg=$yellow]"
                      mode_rename_pane   "#[bg=$yellow,fg=$crust,bold] RENAME#[bg=$surface0,fg=$yellow]"
                      mode_move          "#[bg=$yellow,fg=$crust,bold] MOVE#[bg=$surface0,fg=$yellow]"
                      mode_session       "#[bg=$pink,fg=$crust,bold] SESSION#[bg=$surface0,fg=$pink]"
                      mode_prompt        "#[bg=$pink,fg=$crust,bold] PROMPT#[bg=$surface0,fg=$pink]"

                      // Tab formatting - index in colored pill, name on surface1
                      tab_normal              "#[bg=$surface0,fg=$blue]#[bg=$blue,fg=$crust,bold]{index} #[bg=$surface1,fg=$blue,bold] {name}{floating_indicator}#[bg=$surface0,fg=$surface1]"
                      tab_normal_fullscreen   "#[bg=$surface0,fg=$blue]#[bg=$blue,fg=$crust,bold]{index} #[bg=$surface1,fg=$blue,bold] {name}{fullscreen_indicator}#[bg=$surface0,fg=$surface1]"
                      tab_normal_sync         "#[bg=$surface0,fg=$blue]#[bg=$blue,fg=$crust,bold]{index} #[bg=$surface1,fg=$blue,bold] {name}{sync_indicator}#[bg=$surface0,fg=$surface1]"
                      tab_active              "#[bg=$surface0,fg=$peach]#[bg=$peach,fg=$crust,bold]{index} #[bg=$surface1,fg=$peach,bold] {name}{floating_indicator}#[bg=$surface0,fg=$surface1]"
                      tab_active_fullscreen   "#[bg=$surface0,fg=$peach]#[bg=$peach,fg=$crust,bold]{index} #[bg=$surface1,fg=$peach,bold] {name}{fullscreen_indicator}#[bg=$surface0,fg=$surface1]"
                      tab_active_sync         "#[bg=$surface0,fg=$peach]#[bg=$peach,fg=$crust,bold]{index} #[bg=$surface1,fg=$peach,bold] {name}{sync_indicator}#[bg=$surface0,fg=$surface1]"
                      tab_separator           "#[bg=$surface0] "

                      tab_sync_indicator       " "
                      tab_fullscreen_indicator " 󰊓"
                      tab_floating_indicator   " 󰹙"

                      // Git branch (updates every 10s)
                      command_git_branch_command     "git rev-parse --abbrev-ref HEAD"
                      command_git_branch_format      "{stdout}"
                      command_git_branch_interval    "10"
                      command_git_branch_rendermode  "static"

                      // Host (static)
                      command_host_command    "uname -n"
                      command_host_format     "{stdout}"
                      command_host_interval   "0"
                      command_host_rendermode "static"

                      // User (static)
                      command_user_command    "whoami"
                      command_user_format     "{stdout}"
                      command_user_interval   "0"
                      command_user_rendermode "static"

                      // Datetime (local system time)
                      datetime          "{format}"
                      datetime_format   "%Y-%m-%d 󰅐 %H:%M"
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
