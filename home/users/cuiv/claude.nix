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

      # Plugins
      enabledPlugins = {
        "superpowers@superpowers-marketplace" = true;
        "superpowers-developing-for-claude-code@superpowers-marketplace" = true;
        "episodic-memory@superpowers-marketplace" = true;
        "cuiv-skills@cuiv-skills-marketplace" = true;
      };

      # Extended thinking
      alwaysThinkingEnabled = true;
    };

    # User-level instructions
    ".claude/CLAUDE.md".source = ./claude/CLAUDE.md;

    # Custom agents
    ".claude/agents/bash-script-writer.md".source = ./claude/agents/bash-script-writer.md;
  };
}
