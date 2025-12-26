{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./tools.nix
    ./shell.nix
  ];

  # Home-Manager version - matches NixOS stateVersion
  home.stateVersion = "24.11";

  # Basic home configuration
  home.username = "cuiv";
  home.homeDirectory = "/home/cuiv";

  # Allow Home-Manager to manage itself
  programs.home-manager.enable = true;

  # Shell configuration (Keep bash as fallback)
  programs.bash.enable = true;
}
