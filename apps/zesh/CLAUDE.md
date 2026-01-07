# Zesh

Rust session manager for Zellij. Replaces bash `t` sessionizer.

## COMMANDS

```bash
cargo build              # Build
cargo run                # Interactive picker
cargo run infra          # Fuzzy match + jump
cargo test               # Tests
cargo clippy -- -D warnings  # Lint (warnings = errors)
cargo fmt --check        # Format check
```

## ARCHITECTURE

| File | Purpose |
|------|---------|
| `main.rs` | CLI entry (clap) |
| `config.rs` | TOML config parsing |
| `discovery.rs` | Git repo/worktree discovery |
| `frecency.rs` | Frecency scoring + persistence |
| `zellij.rs` | Session management |
| `picker.rs` | Interactive selection (skim) |

## PATHS

- **Config:** `~/.config/zesh/config.toml`
- **Data:** `~/.local/share/zesh/frecency.json`
- **Design:** `docs/plans/2025-12-26-zesh-session-manager-design.md`

## CONVENTIONS

- `cargo clippy -- -D warnings` must pass
- Tests in `#[cfg(test)]` modules per file
- Dev dependency: `tempfile` for temp file tests
