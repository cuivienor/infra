# Nix Pre-commit Hooks Design

## Overview

Add Nix linting, formatting, and validation to pre-commit hooks for the infra repository.

## Goals

- **Strict quality gates**: Block commits with lint errors, dead code, or formatting issues
- **Auto-fix where possible**: deadnix, statix, and nixfmt all auto-fix in place
- **Agent-friendly harness**: `nix flake check` provides fast feedback loop for coding agents

## Tool Stack

| Tool | Purpose | Auto-fix |
|------|---------|----------|
| deadnix | Find unused bindings/dead code | Yes (`--edit`) |
| statix | Antipattern detection | Yes (`fix` subcommand) |
| nixfmt-rfc-style | Formatting (RFC standard) | Yes (in-place) |
| nix flake check | Validate flake evaluates | N/A |

Run order: deadnix → statix → nixfmt → nix flake check

## Files to Modify

### 1. `flake.nix` (devShell)

Replace `nixpkgs-fmt` with the new tool stack:

```nix
# Nix tooling
deadnix
statix
nixfmt-rfc-style  # replaces nixpkgs-fmt
nil               # Nix LSP (keep)
```

### 2. `home/users/cuiv/tools.nix`

Replace `nixpkgs-fmt` for consistency in home environment:

```nix
# Nix development
nixfmt-rfc-style  # replaces nixpkgs-fmt
nil               # Nix LSP (keep)
```

### 3. `.pre-commit-config.yaml`

Add after shellcheck section:

```yaml
# Nix linting and formatting (requires devShell - run: direnv allow)
- repo: local
  hooks:
    - id: deadnix
      name: deadnix (remove dead code)
      entry: deadnix --edit --no-lambda-arg --no-lambda-pattern-names
      language: system
      files: \.nix$

    - id: statix
      name: statix (fix antipatterns)
      entry: bash -c 'statix fix "$@" && statix check "$@"' --
      language: system
      files: \.nix$

    - id: nixfmt
      name: nixfmt (format)
      entry: nixfmt
      language: system
      files: \.nix$

    - id: nix-flake-check
      name: nix flake check
      entry: nix flake check
      language: system
      files: \.nix$
      pass_filenames: false
```

## Usage

### Prerequisites

Must be in devShell before committing:

```bash
direnv allow  # or: nix develop
```

### Normal workflow

Hooks run automatically on `git commit`. Auto-fixable issues are fixed in place; commit is blocked only on real errors.

### Escape hatches

```bash
# Skip slow nix flake check
SKIP=nix-flake-check git commit -m "message"

# Skip all hooks (emergency only)
git commit --no-verify -m "message"
```

### Manual runs

```bash
pre-commit run deadnix --all-files
pre-commit run statix --all-files
pre-commit run nixfmt --all-files
pre-commit run nix-flake-check --all-files
```

## Files Affected by Hooks

- `flake.nix` - root flake
- `nixos/**/*.nix` - NixOS configurations
- `home/**/*.nix` - Home Manager configurations

## Decision Log

- **nixfmt-rfc-style over nixpkgs-fmt**: RFC-approved standard, nixpkgs is migrating to it
- **Local hooks over external repo**: Matches existing ansible-lint pattern, versions controlled by flake.nix
- **Include nix flake check**: Provides feedback harness for coding agents despite slower execution
