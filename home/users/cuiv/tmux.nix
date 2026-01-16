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

    # Use C-Space as prefix
    prefix = "C-Space";

    # Plugins
    plugins = with pkgs.tmuxPlugins; [
      sensible
      vim-tmux-navigator
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_window_status_style "rounded"
          set-option -g status-position top
          set -g status-right-length 100
          set -g status-left-length 100

          set -g status-left "#{E:@catppuccin_status_session}"
          set -g status-right "#{E:@catppuccin_status_application}"
          set -ag status-right "#{E:@catppuccin_status_uptime}"

          set -g @catppuccin_window_current_text " #{window_name}"
          set -g @catppuccin_window_text " #{window_name}"
          set -g @catppuccin_window_default_text " #{window_name}"
        '';
      }
    ];

    extraConfig = ''
      # True color support
      set -ag terminal-overrides ",xterm-256color:RGB"
      set -g allow-passthrough on

      # Vim-style pane navigation (handled by vim-tmux-navigator plugin)
      # Vim copy mode bindings
      bind -T copy-mode-vi v send-keys -X begin-selection

      # Cross-platform clipboard integration
      if-shell "command -v pbcopy" \
          "bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'pbcopy'; \
           bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel 'pbcopy'" \
          "bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'; \
           bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel 'xclip -in -selection clipboard'"

      # Split panes with s (horizontal) and v (vertical)
      unbind %
      bind s split-window -v -c "#{pane_current_path}"
      unbind '"'
      bind v split-window -h -c "#{pane_current_path}"

      # New windows in current path
      bind c new-window -c "#{pane_current_path}"

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # t sessionizer keybinding
      bind-key -r t neww ~/.config/scripts/t
    '';
  };
}
