# home/profiles/identity/personal.nix
# Personal identity - for non-work machines
{ config, pkgs, lib, ... }:

{
  programs.git.settings.user.email = "peter@petrovs.io";
}
