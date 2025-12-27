# Zesh Development Guide

Rust session manager for zellij. Replaces the bash `t` sessionizer.

## Development

```bash
# Load devShell (automatic with direnv)
cd apps/zesh

# Build
cargo build

# Run
cargo run -- --help
cargo run             # Interactive picker
cargo run infra       # Fuzzy match + jump

# Test
cargo test

# Lint
cargo clippy -- -D warnings
cargo fmt --check
```

## Architecture

| File | Purpose |
|------|---------|
| `main.rs` | CLI entry point (clap) |
| `config.rs` | TOML config parsing |
| `discovery.rs` | Git repo/worktree/sparse-checkout discovery |
| `frecency.rs` | Frecency scoring + JSON persistence |
| `zellij.rs` | Zellij session management |
| `picker.rs` | Interactive selection (skim) |

## Config Location

`~/.config/zesh/config.toml`

## Data Location

`~/.local/share/zesh/frecency.json`

## Design Doc

See `docs/plans/2025-12-26-zesh-session-manager-design.md`
