# macOS-specific configurations
# Conditionally applied only on darwin systems
{
  config,
  pkgs,
  lib,
  ...
}:

{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    # AeroSpace tiling window manager
    xdg.configFile."aerospace/aerospace.toml".source = ./macos/aerospace.toml;

    # Ghostty terminal
    xdg.configFile."ghostty/config".source = ./macos/ghostty.config;

    # Raycast script commands
    home.file = {
      ".local/scripts/raycast/ghostty-new-window.sh" = {
        source = ./macos/raycast/ghostty-new-window.sh;
        executable = true;
      };
      ".local/scripts/raycast/chrome-new-window.sh" = {
        source = ./macos/raycast/chrome-new-window.sh;
        executable = true;
      };
      ".local/scripts/raycast/chrome-work-tabs.sh" = {
        source = ./macos/raycast/chrome-work-tabs.sh;
        executable = true;
      };
    };
  };
}
