{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Peter Petrov";
    userEmail = "peter@petrovs.io";

    extraConfig = {
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

    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = false;
        line-numbers = true;
      };
    };
  };
}
