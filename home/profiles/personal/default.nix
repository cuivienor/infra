# home/profiles/personal/default.nix
{ config, pkgs, lib, ... }:

{
  # Personal profile - for non-work machines
  imports = [
    ./claude.nix # Claude Code binary (native installer via Nix)
    ../../users/cuiv/opencode/personal.nix
  ];
}
