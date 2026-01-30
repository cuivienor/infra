# home/profiles/identity/shopify.nix
# Shopify work identity
{ config, pkgs, lib, ... }:

{
  programs.git = {
    settings.user.email = "peter.petrov@shopify.com";

    # Include Shopify's dev gitconfig
    includes = [
      { path = "~/.config/dev/gitconfig"; }
    ];
  };
}
