{ config, pkgs, ... }:

{
  # Claude Code configuration
  # Managed by Home Manager - syncs ~/.claude/ directory

  home.file = {
    # Main settings
    ".claude/settings.json".text = builtins.toJSON {
      permissions = {
        allow = [
          # File operations
          "Read"
          "Glob"
          "Grep"
          "Write"
          "Edit"

          # Skills and tasks
          "Skill(superpowers:*)"
          "Task"

          # Git commands
          "Bash(git status:*)"
          "Bash(git diff:*)"
          "Bash(git log:*)"
          "Bash(git show:*)"
          "Bash(git branch:*)"
          "Bash(git worktree:*)"
          "Bash(git add:*)"
          "Bash(git commit:*)"
          "Bash(git rev-parse:*)"

          # Basic shell commands
          "Bash(cd:*)"
          "Bash(chmod:*)"
          "Bash(ls:*)"
          "Bash(cat:*)"
          "Bash(pwd:*)"
          "Bash(mkdir:*)"

          # Package managers
          "Bash(npm:*)"
          "Bash(yarn:*)"

          # Utilities
          "Bash(jq:*)"

          # Web access
          "WebFetch(domain:docs.anthropic.com)"
        ];
      };

      # Status line (using npx, works with Node.js)
      statusLine = {
        type = "command";
        command = "npx -y ccstatusline";
      };

      # Plugins
      enabledPlugins = {
        "superpowers@superpowers-marketplace" = true;
        "superpowers-developing-for-claude-code@superpowers-marketplace" = true;
        "episodic-memory@superpowers-marketplace" = true;
        "cuiv-skills@cuiv-skills-marketplace" = true;
      };

      # Extended thinking
      alwaysThinkingEnabled = true;

      # Override default model (opus alias auto-updates to latest)
      model = "claude-opus-4-5";
    };

    # User-level instructions
    ".claude/CLAUDE.md".source = ./claude/CLAUDE.md;

    # Custom agents
    ".claude/agents/bash-script-writer.md".source = ./claude/agents/bash-script-writer.md;

    # ccstatusline configuration with Catppuccin Mocha colors
    ".config/ccstatusline/settings.json".text = builtins.toJSON {
      version = 3;
      lines = [
        [
          {
            id = "1";
            type = "model";
            color = "hex:89b4fa";
          }
          {
            id = "2";
            type = "separator";
          }
          {
            id = "3";
            type = "context-length";
            color = "hex:94e2d5";
          }
          {
            id = "4";
            type = "separator";
          }
          {
            id = "5";
            type = "context-percentage";
            color = "hex:a6e3a1";
          }
          {
            id = "6";
            type = "separator";
          }
          {
            id = "7";
            type = "git-branch";
            color = "hex:cba6f7";
          }
          {
            id = "8";
            type = "separator";
          }
          {
            id = "9";
            type = "git-changes";
            color = "hex:fab387";
          }
          {
            id = "10";
            type = "separator";
          }
          {
            id = "11";
            type = "session-cost";
            color = "hex:a6e3a1";
          }
          {
            id = "12";
            type = "separator";
          }
          {
            id = "13";
            type = "block-timer";
            color = "hex:f9e2af";
          }
        ]
        [ ]
        [ ]
      ];
      flexMode = "full-minus-40";
      compactThreshold = 60;
      colorLevel = 3;
      inheritSeparatorColors = false;
      globalBold = false;
      powerline = {
        enabled = false;
        separators = [ "\ue0b0" ];
        separatorInvertBackground = [ true ];
        startCaps = [ ];
        endCaps = [ ];
        autoAlign = false;
      };
    };
  };
}
