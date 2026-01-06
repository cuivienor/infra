{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Ensure Node.js available for npm global install of opencode
  # nodejs_22 already in tools.nix, but we depend on it explicitly
  home.packages = with pkgs; [
    nodejs_22
  ];

  # Base opencode configuration
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    # oh-my-opencode as plugin
    plugins = [
      "oh-my-opencode@latest"
    ];

    # Shell config - use zsh with login shell for direnv
    shell = {
      path = "${pkgs.zsh}/bin/zsh";
      args = [ "-l" ];
    };
  };

  # Base oh-my-opencode config (shared settings)
  xdg.configFile."opencode/oh-my-opencode.json".text = builtins.toJSON {
    # Enable Claude Code compatibility - share ~/.claude/ config
    claude_code = {
      commands = true;
      skills = true;
      agents = true;
      mcps = true;
      hooks = true;
    };

    # Agent defaults - profiles can override
    agents = { };

    # Recommended experimental features
    experimental = {
      preemptive_compaction = true;
      preemptive_compaction_threshold = 0.80;
    };
  };
}
