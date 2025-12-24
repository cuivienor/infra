# Session Manager

Tmux session management utility (based on ThePrimeagen's tmux-sessionizer).

## Purpose

The `t` script provides fast project switching via tmux:
- Discovers git repos in `~/dev`, `~/src`, and configurable paths
- Uses fzf for interactive selection
- Creates/switches tmux sessions per project
- Supports `.t` files for project-specific initialization

## Development

```bash
# Enter devShell with bash tooling
nix develop .#session-manager

# Lint
shellcheck t

# Format
shfmt -w t
```

## How It Works

1. `find_projects()` discovers git repos in known directories
2. User selects via fzf (or passes path as argument)
3. Creates tmux session named after directory (dots → underscores)
4. Sources `.t` file if present in project root
5. Attaches or switches to session

## Key Functions

| Function | Purpose |
|----------|---------|
| `switch_to` | Attach or switch based on TMUX context |
| `has_session` | Check if session exists |
| `tmux_init` | Source project `.t` file |
| `find_projects` | Discover git repos in known paths |

## Evolution Plans

This script will evolve to support:
- Zellij as alternative to tmux
- Configuration file for custom search paths
- Session templates beyond `.t` files

## Testing

No automated tests currently. Manual testing:

```bash
# Direct path
./t ~/dev/infra

# Fuzzy search
./t infra

# Interactive selection
./t
```

## Dotfiles Integration

The script lives here but is symlinked via stow:
- `dotfiles/stow/scripts/.local/scripts/t` → `apps/session-manager/t`

Changes here automatically apply to stowed environments.
