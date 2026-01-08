# home/profiles/shopify/default.nix
{ config, pkgs, lib, ... }:

{
  # Shopify work profile
  # Imports all Shopify-specific modules
  imports = [
    ./shell.nix
    ./git.nix
    # claude.nix and opencode managed manually outside of Nix
  ];
}
