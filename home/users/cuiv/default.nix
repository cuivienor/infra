{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
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

  # Useful CLI tools
  home.packages = with pkgs; [
    # Development
    nixpkgs-fmt
    nil  # Nix LSP

    # CLI utilities
    bat
    eza
    fzf
    zoxide
    delta
  ];
}
