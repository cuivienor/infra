{ lib, ... }:

{
  programs.ssh = {
    enable = true;

    # Opt out of deprecated default config (will be removed in future HM)
    # We explicitly set the defaults we want in the "*" matchBlock
    enableDefaultConfig = lib.mkDefault false;

    matchBlocks = {
      # Global defaults (replaces deprecated built-in defaults)
      "*" = {
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "/home/cuiv/.ssh/github-devbox";
        identitiesOnly = true;
      };
    };
  };
}
