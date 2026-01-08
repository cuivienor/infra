# macOS-specific configurations
# Conditionally applied only on darwin systems
{ config, pkgs, lib, ... }:

{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    # AeroSpace tiling window manager
    xdg.configFile."aerospace/aerospace.toml".source = ./macos/aerospace.toml;

    # Ghostty terminal
    xdg.configFile."ghostty/config".source = ./macos/ghostty.config;
  };
}
