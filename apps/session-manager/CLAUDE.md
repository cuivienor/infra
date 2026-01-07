# Session Manager

Bash tmux sessionizer (ThePrimeagen-inspired). Being replaced by `apps/zesh/`.

## COMMANDS

```bash
./t              # Interactive fzf picker
./t infra        # Fuzzy match + jump
./t ~/dev/infra  # Direct path

# Development
shellcheck t     # Lint
shfmt -w t       # Format
```

## HOW IT WORKS

1. Discovers git repos in `~/dev`, `~/src`
2. User selects via fzf
3. Creates/switches tmux session
4. Sources `.t` file if present

## KEY FUNCTIONS

| Function | Purpose |
|----------|---------|
| `switch_to` | Attach/switch based on context |
| `has_session` | Check session exists |
| `find_projects` | Discover git repos |

## INTEGRATION

Symlinked via stow: `dotfiles/stow/scripts/.local/scripts/t`

## FUTURE

Being replaced by `apps/zesh/` (Rust, Zellij support).
