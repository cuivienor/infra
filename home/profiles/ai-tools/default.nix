# home/profiles/ai-tools/default.nix
# Self-managed AI tooling (for machines where employer doesn't manage these)
{ config, pkgs, lib, ... }:

{
  imports = [
    ./claude.nix # Claude Code binary + settings
    ../../users/cuiv/opencode/personal.nix # opencode with OAuth plugins
  ];
}
