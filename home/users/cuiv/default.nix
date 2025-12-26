{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./tools.nix
    ./shell.nix
  ];

  # Home-Manager version and basic configuration
  home = {
    stateVersion = "24.11";
    username = "cuiv";
    homeDirectory = "/home/cuiv";
  };

  # Programs managed by Home-Manager
  programs = {
    home-manager.enable = true;
    bash.enable = true; # Keep bash as fallback
  };
}
