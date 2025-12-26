# Zesh: Session Manager Design

A Rust CLI for fast terminal session management with zellij, supporting git worktrees and sparse checkout zones.

## Overview

**What:** Replace the bash `t` sessionizer with a Rust tool that:
- Discovers projects across configurable roots (git repos, worktrees, sparse zones)
- Uses zellij as the multiplexer backend
- Supports per-project `.zellij.kdl` layouts (native zellij format)
- Context-aware ordering (current project's siblings first)
- Frecency-based sorting

**Why:** Current `t` script has hardcoded paths, limited worktree/sparse-checkout support, and tmux-specific initialization.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                         CLI                             │
│       zesh, zesh ls, zesh kill, zesh clean, zesh config       │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                    Core Logic                           │
│       ┌─────────────┐           ┌─────────────┐        │
│       │  Discovery  │           │  Frecency   │        │
│       └─────────────┘           └─────────────┘        │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│              Multiplexer Backend (trait)                │
│  ┌─────────────────────┐  ┌────────────────────────┐   │
│  │  ZellijBackend      │  │  TmuxBackend (future)  │   │
│  └─────────────────────┘  └────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Project Discovery

### Project Types

All discovered items are "projects" with different origins:

```rust
struct Project {
    name: String,              // Display name for picker
    path: PathBuf,             // Absolute path to open
    repo_root: PathBuf,        // Git repo root
    worktree_branch: Option<String>,  // If worktree, which branch
    sparse_zone: Option<String>,      // If sparse checkout, zone path
}
```

### Discovery Rules

1. **Regular repos:** Walk roots up to configured depth, find `.git` dirs
2. **Worktrees:** Run `git worktree list`, each becomes separate project (`repo/branch`)
3. **Sparse zones:** If repo uses sparse checkout, run `git sparse-checkout list`, each zone becomes project

### Naming

- Regular repo: `basename` (or `parent/basename` if collision)
- Worktree: `repo/branch`
- Sparse zone: zone path suffix (last N segments)
- Worktree + sparse zone: `repo/branch/zone-suffix`

### Context-Aware Ordering

When selecting from picker while in `world/main/areas/core/shopify`:

1. **Same worktree, other zones:** `world/main/areas/platform/payments`
2. **Other worktrees, same zone:** `world/feature-x/areas/core/shopify`
3. **Everything else:** sorted by frecency

## Configuration

Location: `~/.config/zesh/config.toml`

```toml
# Search roots
[[roots]]
path = "~/dev"
depth = 2

[[roots]]
path = "~/src"
depth = 3

[[roots]]
path = "~/world"
depth = 1
sparse_checkout = true
```

That's it. No template configuration - layouts are native KDL files.

## Layouts

**Per-project:** Place `.zellij.kdl` in project root (optional, can commit to git)

**Global fallback:** `~/.config/zellij/layouts/default.kdl`

**Session creation logic:**
```
if project has .zellij.kdl:
    zellij --layout .zellij.kdl --session "$name" --new-session-with-layout
else:
    zellij --layout default --session "$name" --new-session-with-layout
```

**Example `.zellij.kdl`:**
```kdl
layout {
    tab name="code" focus=true {
        pane command="nvim" { args "." }
    }
    tab name="scratch" {
        pane
    }
}
```

This approach:
- No KDL generation, no translation layer
- Projects own their layouts (can version control)
- You learn zellij's native format directly
- Simpler implementation

## CLI Interface

```bash
zesh              # Interactive picker (fzf-style, context-aware)
zesh <query>      # Fuzzy match + jump
zesh ls           # List active zellij sessions
zesh kill <name>  # Kill a session
zesh clean        # Kill sessions for non-existent projects
zesh config       # Open config in $EDITOR
```

## Data Storage

Location: `~/.local/share/zesh/`

**Files:**
- `frecency.json` - access frequency + recency scores

**No discovery cache.** Project discovery runs on every invocation:
- Directory walking with `ignore` crate is ~10ms
- Git worktree/sparse-checkout detection is fast enough
- Simpler code, no stale data, no cache invalidation

## Crate Recommendations

| Purpose | Crate |
|---------|-------|
| CLI parsing | `clap` |
| Config parsing | `toml`, `serde` |
| Directory walking | `ignore` (ripgrep's crate) |
| Fuzzy picker | `skim` (fzf clone in Rust) |
| JSON serialization | `serde_json` |
| Path expansion | `shellexpand` |
| Error handling | `anyhow` |

## File Structure

```
apps/zesh/
├── Cargo.toml
├── src/
│   ├── main.rs           # CLI entry point
│   ├── config.rs         # Config parsing
│   ├── discovery.rs      # Project discovery (on-demand)
│   ├── frecency.rs       # Frecency scoring + persistence
│   ├── zellij.rs         # Zellij session commands
│   └── picker.rs         # Interactive selection
└── tests/
    └── ...
```

## Implementation Phases

### Phase 1: Core Discovery + Picker
- Config parsing (roots, depths)
- Git repo discovery with `ignore` crate
- Simple picker with skim
- Zellij session creation with layout detection (.zellij.kdl or default)

### Phase 2: Worktrees + Sparse Zones
- `git worktree list` integration
- `git sparse-checkout list` integration
- Combined naming scheme

### Phase 3: Polish
- Frecency tracking + persistence
- Context-aware ordering
- Session management (ls, kill, clean)

## Migration Path

1. Build zesh alongside existing `t` script
2. Alias `zesh` to `t` once feature-complete
3. Remove old bash script
4. Update dotfiles stow package

## Decisions

- **Multiplexer abstraction:** Yes - keep backend trait, implement zellij only for now
- **Session naming collisions:** Include parent dir (e.g., `org/api` instead of just `api`)
