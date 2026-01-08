_:

{
  programs.ssh = {
    enable = true;

    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "/home/cuiv/.ssh/github-devbox";
        identitiesOnly = true;
      };
    };
  };
}
