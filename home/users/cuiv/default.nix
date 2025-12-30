{
  config,
  pkgs,
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
