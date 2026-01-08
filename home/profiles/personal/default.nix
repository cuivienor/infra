# home/profiles/personal/default.nix
{ config, pkgs, lib, ... }:

{
  # Personal profile - for non-work machines
  # Currently just imports opencode personal config
  imports = [
    ../../users/cuiv/opencode/personal.nix
  ];
}
