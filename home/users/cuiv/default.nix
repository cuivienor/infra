{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    ./git.nix
    ./tools.nix
    ./shell.nix
    ./neovim.nix
    ./claude.nix
  ];

  # Pass inputs to imported modules
  _module.args = { inherit inputs; };

  # Home-Manager version and identity
  # username and homeDirectory are set via flake.nix homeConfigurations
  # or inferred by NixOS module - these are fallback defaults
  home = {
    stateVersion = "24.11";
    username = lib.mkDefault "cuiv";
    homeDirectory = lib.mkDefault (if pkgs.stdenv.isDarwin then "/Users/cuiv" else "/home/cuiv");
  };

  # Enable generic Linux support for non-NixOS (Arch, Ubuntu, etc.)
  # This fixes XDG_DATA_DIRS, font paths, and other environment issues
  targets.genericLinux.enable = pkgs.stdenv.isLinux;

  # Programs managed by Home-Manager
  programs = {
    home-manager.enable = true;
    bash.enable = true; # Keep bash as fallback
  };
}
