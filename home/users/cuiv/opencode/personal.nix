{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ ./default.nix ];

  # Override opencode.json to add OAuth auth plugins
  xdg.configFile."opencode/opencode.json".text = lib.mkForce (
    builtins.toJSON {
      plugins = [
        "oh-my-opencode@latest"
        "opencode-antigravity-auth@1.1.2" # Gemini OAuth
        "opencode-openai-codex-auth@4.1.1" # ChatGPT OAuth
      ];

      shell = {
        path = "${pkgs.zsh}/bin/zsh";
        args = [ "-l" ];
      };

      # Providers configured via OAuth - no API keys in config
      # Run `opencode auth login` after install to authenticate each provider
    }
  );

  # Personal oh-my-opencode overrides
  xdg.configFile."opencode/oh-my-opencode.json".text = lib.mkForce (
    builtins.toJSON {
      claude_code = {
        commands = true;
        skills = true;
        agents = true;
        mcps = true;
        hooks = true;
      };

      # Use Antigravity plugin for Google auth (disable built-in)
      google_auth = false;

      agents = { };

      experimental = {
        preemptive_compaction = true;
        preemptive_compaction_threshold = 0.80;
      };
    }
  );
}
