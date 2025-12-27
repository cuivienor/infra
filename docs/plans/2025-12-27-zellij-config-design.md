# Zellij Configuration Design

Design for migrating from tmux to zellij, replicating the current workflow as closely as possible while embracing zellij's paradigms.

## Goals

- Replicate tmux workflow with catppuccin theme
- Use zellij's mode-based approach (not tmux prefix simulation)
- zjstatus for customizable status bar
- Manage config via Nix/Home Manager

## Current tmux Setup (Reference)

### Plugins
- tpm (plugin manager)
- tmux-sensible (sane defaults)
- catppuccin/tmux (theme)
- vim-tmux-navigator (Ctrl+hjkl navigation)

### Keybindings
- `Ctrl+Space` - Prefix
- `prefix+s` - Horizontal split
- `prefix+v` - Vertical split
- `prefix+t` - Sessionizer
- Copy mode: `v` select, `y` yank to clipboard

### Status Bar
- Position: Top
- Left: Session name
- Right: Application + Uptime
- Style: Catppuccin rounded windows

### Default Layout
- Tab 1: nvim
- Tab 2: claude
- Tab 3: git (lazygit + shell panes)
- Tab 4: scratch
- Tab 9: servers (long-running processes)

## Zellij Design Decisions

### Mode Paradigm
**Decision:** Embrace zellij's native mode system, not simulate tmux prefix.

- `Ctrl+g` toggles locked mode (all keys to terminal)
- `Ctrl+p` pane mode, `Ctrl+t` tab mode, `Ctrl+s` scroll mode
- Learn native keybindings for splits: `Ctrl+p` → `d`/`r`

### Pane Navigation
**Decision:** Custom `Ctrl+hjkl` bindings (preserves muscle memory).

```kdl
shared_except "locked" {
    bind "Ctrl h" { MoveFocus "Left"; }
    bind "Ctrl j" { MoveFocus "Down"; }
    bind "Ctrl k" { MoveFocus "Up"; }
    bind "Ctrl l" { MoveFocus "Right"; }
}
```

Trade-off: Loses `Ctrl+l` for clear screen (use `clear` command instead).

### Status Bar
**Decision:** zjstatus plugin with catppuccin mocha colors.

- Mode indicator on left (NORMAL/LOCKED/PANE/SCROLL)
- Tabs in center-left
- Session name on right
- Matches tmux catppuccin aesthetic

### Servers Tab
**Decision:** Use floating pane instead of tab 9.

Zellij tabs are sequential (can't have gaps). Floating pane is actually better:
- Available from any tab with `Ctrl+p` → `w`
- Can overlay current work to check logs
- Dismiss when not needed

### Scrollback & Copy Mode
**Decision:** 50,000 lines, vim keybindings, system clipboard.

```kdl
scrollback_lines 50000
copy_on_select true
copy_command "xclip -selection clipboard"
mouse_mode true
```

### Config Management
**Decision:** Separate KDL files managed by Home Manager.

- Complex KDL configs benefit from native syntax highlighting
- Easier to iterate on layouts
- zjstatus plugin managed via Nix flake input

## File Structure

```
~/.config/zellij/
├── config.kdl           # Main config
├── layouts/
│   └── default.kdl      # 4-tab layout with zjstatus
└── plugins/
    └── zjstatus.wasm    # Managed by Nix

home/users/cuiv/
├── tools.nix            # Home Manager config
└── zellij/
    ├── config.kdl       # Source files
    └── layouts/
        └── default.kdl
```

## Key Zellij Commands to Learn

| Action | Command |
|--------|---------|
| Toggle locked mode | `Ctrl+g` |
| Pane mode | `Ctrl+p` |
| Tab mode | `Ctrl+t` |
| Scroll mode | `Ctrl+s` |
| Split down | `Ctrl+p` → `d` |
| Split right | `Ctrl+p` → `r` |
| Floating pane | `Ctrl+p` → `w` |
| Navigate panes | `Ctrl+hjkl` (custom) |
| Close pane | `Ctrl+p` → `x` |
| New tab | `Ctrl+t` → `n` |

## References

- [Catppuccin Zellij](https://github.com/catppuccin/zellij)
- [zjstatus Plugin](https://github.com/dj95/zjstatus)
- [Zellij Keybindings](https://zellij.dev/documentation/keybindings)
- [Zellij Layouts](https://zellij.dev/documentation/layouts)
