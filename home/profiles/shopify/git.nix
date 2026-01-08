# home/profiles/shopify/git.nix
{ config, pkgs, lib, ... }:

{
  programs.git = {
    # Override email for work
    settings.user.email = lib.mkForce "peter.petrov@shopify.com";

    # Include Shopify's dev gitconfig
    includes = [
      { path = "~/.config/dev/gitconfig"; }
    ];
  };
}
