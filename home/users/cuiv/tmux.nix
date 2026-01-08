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
