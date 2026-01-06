# OpenCode + Oh-My-OpenCode Home Manager Setup

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add opencode with oh-my-opencode plugin to home-manager with profile-based separation for personal (OAuth) vs work (proxy) environments.

**Architecture:** Layered Nix modules - shared base config in `opencode/default.nix`, profile-specific overrides in `personal.nix` and `work.nix`. OAuth tokens managed outside home-manager via `opencode auth login`. Claude Code compatibility enabled to share existing `~/.claude/` config.

**Tech Stack:** Nix/Home Manager, OpenCode (npm), Oh-My-OpenCode plugin, JSONC config files

---

## Task 1: Create Shared OpenCode Base Module

**Files:**
- Create: `home/users/cuiv/opencode/default.nix`

**Step 1: Create the opencode directory**

```bash
mkdir -p home/users/cuiv/opencode
```

**Step 2: Write the base module**

Create `home/users/cuiv/opencode/default.nix`:

```nix
{ config, pkgs, lib, ... }:

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
    agents = {};

    # Recommended experimental features
    experimental = {
      preemptive_compaction = true;
      preemptive_compaction_threshold = 0.80;
    };
  };
}
```

**Step 3: Verify syntax**

```bash
nix-instantiate --parse home/users/cuiv/opencode/default.nix
```

Expected: No errors, outputs parsed expression

**Step 4: Commit**

```bash
git add home/users/cuiv/opencode/default.nix
git commit -m "feat(home): add opencode base module with oh-my-opencode"
```

---

## Task 2: Create Personal Profile Module

**Files:**
- Create: `home/users/cuiv/opencode/personal.nix`

**Step 1: Write the personal profile**

Create `home/users/cuiv/opencode/personal.nix`:

```nix
{ config, pkgs, lib, ... }:

{
  imports = [ ./default.nix ];

  # Override opencode.json to add OAuth auth plugins
  xdg.configFile."opencode/opencode.json".text = lib.mkForce (builtins.toJSON {
    plugins = [
      "oh-my-opencode@latest"
      "opencode-antigravity-auth@1.1.2"    # Gemini OAuth
      "opencode-openai-codex-auth@4.1.1"   # ChatGPT OAuth
    ];

    shell = {
      path = "${pkgs.zsh}/bin/zsh";
      args = [ "-l" ];
    };

    # Providers configured via OAuth - no API keys in config
    # Run `opencode auth login` after install to authenticate each provider
  });

  # Personal oh-my-opencode overrides
  xdg.configFile."opencode/oh-my-opencode.json".text = lib.mkForce (builtins.toJSON {
    claude_code = {
      commands = true;
      skills = true;
      agents = true;
      mcps = true;
      hooks = true;
    };

    # Use Antigravity plugin for Google auth (disable built-in)
    google_auth = false;

    agents = {};

    experimental = {
      preemptive_compaction = true;
      preemptive_compaction_threshold = 0.80;
    };
  });
}
```

**Step 2: Verify syntax**

```bash
nix-instantiate --parse home/users/cuiv/opencode/personal.nix
```

Expected: No errors

**Step 3: Commit**

```bash
git add home/users/cuiv/opencode/personal.nix
git commit -m "feat(home): add opencode personal profile with OAuth plugins"
```

---

## Task 3: Create Work Profile Module

**Files:**
- Create: `home/users/cuiv/opencode/work.nix`

**Step 1: Write the work profile**

Create `home/users/cuiv/opencode/work.nix`:

```nix
{ config, pkgs, lib, ... }:

{
  imports = [ ./default.nix ];

  # Override opencode.json for work proxy
  xdg.configFile."opencode/opencode.json".text = lib.mkForce (builtins.toJSON {
    plugins = [
      "oh-my-opencode@latest"
      # No OAuth plugins - proxy handles all auth
    ];

    shell = {
      path = "${pkgs.zsh}/bin/zsh";
      args = [ "-l" ];
    };

    # Work proxy provider - credentials from environment
    providers = {
      work-proxy = {
        baseURL = "{env:WORK_AI_PROXY_URL}";
        apiKey = "{env:WORK_AI_PROXY_TOKEN}";
      };
    };
  });

  # Work oh-my-opencode config with model mappings
  xdg.configFile."opencode/oh-my-opencode.json".text = lib.mkForce (builtins.toJSON {
    claude_code = {
      commands = true;
      skills = true;
      agents = true;
      mcps = true;
      hooks = true;
    };

    # No OAuth at work
    google_auth = false;

    # Model mappings for work proxy
    # Adjust these based on what models the proxy exposes
    agents = {
      sisyphus = {
        model = "work-proxy/claude-opus-4-5";
      };
      oracle = {
        model = "work-proxy/gpt-4o";
      };
      librarian = {
        model = "work-proxy/claude-sonnet-4";
      };
      explore = {
        model = "work-proxy/claude-haiku";
      };
      frontend-ui-ux-engineer = {
        model = "work-proxy/gemini-2.0-flash";
      };
      document-writer = {
        model = "work-proxy/gemini-2.0-flash";
      };
      multimodal-looker = {
        model = "work-proxy/gemini-2.0-flash";
      };
    };

    experimental = {
      preemptive_compaction = true;
      preemptive_compaction_threshold = 0.80;
    };
  });
}
```

**Step 2: Verify syntax**

```bash
nix-instantiate --parse home/users/cuiv/opencode/work.nix
```

Expected: No errors

**Step 3: Commit**

```bash
git add home/users/cuiv/opencode/work.nix
git commit -m "feat(home): add opencode work profile with proxy config"
```

---

## Task 4: Update Default Module to Import OpenCode

**Files:**
- Modify: `home/users/cuiv/default.nix`

**Step 1: Read current file**

Check current imports in `home/users/cuiv/default.nix`

**Step 2: Add opencode import**

Add to imports list - but note: the specific profile (personal/work) should be imported at the flake level, not here. The base opencode module can be imported here for machines that will always have opencode.

For now, do NOT add to default.nix imports. Instead, profiles are imported per-machine in flake.nix.

**Step 3: Document the pattern**

The import happens at flake level:

```nix
# In flake.nix homeConfigurations:
# Personal machines:
imports = [ ./home/users/cuiv ./home/users/cuiv/opencode/personal.nix ];

# Work machines:
imports = [ ./home/users/cuiv ./home/users/cuiv/opencode/work.nix ];
```

**Step 4: Commit docs update if needed**

No file changes needed for this task - pattern documented in plan.

---

## Task 5: Add to Devbox Configuration

**Files:**
- Modify: `flake.nix` (homeConfigurations section)

**Step 1: Locate homeConfigurations in flake.nix**

Find where `homeConfigurations` or NixOS modules import home-manager.

**Step 2: Add personal profile import for devbox**

If using standalone home-manager:
```nix
homeConfigurations."cuiv@devbox" = home-manager.lib.homeManagerConfiguration {
  # ...
  modules = [
    ./home/users/cuiv
    ./home/users/cuiv/opencode/personal.nix
  ];
};
```

If using NixOS module (devbox is NixOS):
The home-manager module in `nixos/hosts/devbox/configuration.nix` imports from `home/users/cuiv`. Add the opencode profile there.

**Step 3: Verify with dry-run**

```bash
# For NixOS:
nixos-rebuild dry-build --flake .#devbox

# For standalone home-manager:
home-manager build --flake .#cuiv@devbox
```

**Step 4: Commit**

```bash
git add flake.nix  # or nixos/hosts/devbox/configuration.nix
git commit -m "feat(devbox): enable opencode with personal profile"
```

---

## Task 6: Test the Configuration

**Step 1: Apply home-manager config**

```bash
# On devbox:
sudo nixos-rebuild switch --flake .#devbox

# Or for standalone:
home-manager switch --flake .#cuiv@devbox
```

**Step 2: Verify config files deployed**

```bash
ls -la ~/.config/opencode/
cat ~/.config/opencode/opencode.json
cat ~/.config/opencode/oh-my-opencode.json
```

Expected: Both files exist with correct content

**Step 3: Install opencode globally**

```bash
npm i -g opencode-ai@latest
```

**Step 4: Launch opencode**

```bash
opencode
```

Expected: TUI launches, oh-my-opencode plugin auto-installs

**Step 5: Authenticate (personal profile)**

```bash
opencode auth login
# Select Anthropic -> complete OAuth
# Gemini and ChatGPT handled by their plugins
```

**Step 6: Commit any fixes**

```bash
git add -A
git commit -m "fix(home): opencode config adjustments from testing"
```

---

## Task 7: Update Zellij Layout (Optional)

**Files:**
- Modify: `home/users/cuiv/zellij/layouts/default.kdl`

**Step 1: Consider adding opencode tab**

Current layout has: nvim, claude, git, scratch

Option: Replace or add alongside claude tab:

```kdl
tab name="opencode" {
    pane command="zsh" {
        args "-ic" "opencode"
    }
}
```

**Step 2: Decide if needed**

If you want both Claude Code and OpenCode available:
- Keep both tabs, or
- Use scratch tab to launch whichever agent you need

**Step 3: Commit if changed**

```bash
git add home/users/cuiv/zellij/layouts/default.kdl
git commit -m "feat(zellij): add opencode tab to default layout"
```

---

## Post-Implementation Notes

### First Run Checklist

**Personal machines:**
1. `npm i -g opencode-ai@latest`
2. `opencode` (launches TUI, plugins install)
3. `opencode auth login` for each provider

**Work machines:**
1. Set environment variables:
   ```bash
   export WORK_AI_PROXY_URL="https://your-proxy.company.com/v1"
   export WORK_AI_PROXY_TOKEN="your-token"
   ```
2. `npm i -g opencode-ai@latest`
3. `opencode` (should work immediately with proxy)

### Iterating on Model Names

Work profile has placeholder model names. Update `work.nix` agents section based on what your proxy actually exposes. Common patterns:
- `provider/model-name` (e.g., `work-proxy/claude-opus-4-5`)
- `model-name` directly if proxy normalizes

### Claude Code Compatibility

Your existing `~/.claude/` directory is shared:
- `~/.claude/agents/bash-script-writer.md` → available in opencode
- Superpowers skills → available via Claude Code compat layer
- MCP configs from `.mcp.json` → loaded by oh-my-opencode
