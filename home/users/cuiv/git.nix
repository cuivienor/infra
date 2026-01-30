{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;

    # Git settings (new 25.11 format)
    settings = {
      # Name is universal; email comes from identity profile
      user.name = "Peter Petrov";

      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;

      diff.algorithm = "histogram";

      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        lg = "log --oneline --graph --decorate";
      };
    };
  };

  # Delta (moved to programs.delta in 25.11)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = false;
      line-numbers = true;
    };
  };
}
