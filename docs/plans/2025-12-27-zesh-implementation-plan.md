# Zesh Implementation Plan

Comprehensive implementation plan for zesh, a Rust CLI session manager with Nix packaging and Home Manager integration.

## Context

**Design doc:** `docs/plans/2025-12-26-zesh-session-manager-design.md`

**Goal:** Create a Rust CLI (`zesh`) that replaces the bash `t` sessionizer, with:
- Nix-based development environment
- Nix package derivation for deployment
- Home Manager integration for devbox installation

**Key constraints:**
- Must integrate with existing flake.nix patterns
- Must work with current Home Manager setup in `home/users/cuiv/`
- Should follow established app patterns from `apps/media-pipeline/`

---

## Architecture Decisions

### Rust Nix Packaging: naersk

**Choice:** Use [naersk](https://github.com/nix-community/naersk) for Rust → Nix packaging

**Why naersk over alternatives:**
- **Simpler than crane** - single derivation setup, less configuration
- **Better caching than buildRustPackage** - separates deps from source
- **No IFD** - works well with Nix sandboxing and Hydra
- **Matches your complexity level** - you're not doing advanced CI pipelines

**Trade-offs accepted:**
- Uses nixpkgs Rust version by default (acceptable for this project)
- Less granular derivation control than crane (not needed)

### Package Location: Flake Overlay

**Choice:** Define zesh package in `flake.nix` via overlay, not separate package file

**Why:**
- Matches your current flake structure (no overlays/ directory yet)
- Single source of truth for package definition
- Overlay makes it available to both NixOS and Home Manager via `pkgs.zesh`

### Home Manager Integration: tools.nix

**Choice:** Add zesh to `home.packages` in `home/users/cuiv/tools.nix`

**Why:**
- Consistent with how you already manage user packages (ripgrep, fd, etc.)
- No need for a separate module - zesh has no complex configuration
- Simple `home.packages = [ pkgs.zesh ];` pattern

---

## File Structure

```
infra/
├── flake.nix                    # [MODIFY] Add naersk input, overlay, devShell
├── apps/
│   └── zesh/                    # [CREATE] New Rust application
│       ├── Cargo.toml
│       ├── Cargo.lock
│       ├── .envrc               # use flake ../.#zesh
│       ├── .gitignore
│       ├── CLAUDE.md            # Development guidance
│       └── src/
│           ├── main.rs          # CLI entry point
│           ├── config.rs        # Config parsing
│           ├── discovery.rs     # Project discovery
│           ├── frecency.rs      # Frecency scoring
│           ├── zellij.rs        # Zellij backend
│           └── picker.rs        # Interactive selection
└── home/
    └── users/cuiv/
        └── tools.nix            # [MODIFY] Add pkgs.zesh to packages
```

---

## Implementation Tasks

### Phase 1: Nix Infrastructure Setup

#### Task 1.1: Add naersk to flake inputs

**File:** `flake.nix`

**Changes:**
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  home-manager = {
    url = "github:nix-community/home-manager/release-24.11";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # ADD: Rust packaging
  naersk = {
    url = "github:nix-community/naersk";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

**Verification:**
```bash
nix flake lock --update-input naersk
nix flake check
```

---

#### Task 1.2: Define zesh package via overlay

**File:** `flake.nix`

**Changes:** Add overlay in `outputs` section:
```nix
outputs = { self, nixpkgs, home-manager, naersk, ... }@inputs:
let
  system = "x86_64-linux";

  # Overlay that adds zesh package
  zeshOverlay = final: prev: {
    zesh = let
      naersk' = prev.callPackage naersk {};
    in naersk'.buildPackage {
      src = ./apps/zesh;
      nativeBuildInputs = [ prev.pkg-config ];
      buildInputs = [ prev.openssl ];  # If needed for HTTPS
    };
  };

  # Apply overlay to pkgs
  pkgs = import nixpkgs {
    inherit system;
    overlays = [ zeshOverlay ];
  };

  pkgsUnfree = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ zeshOverlay ];
  };
in
{
  # ... rest of outputs
};
```

**Note:** The overlay is applied to BOTH pkgs and pkgsUnfree so zesh is available everywhere.

**Verification:**
```bash
nix build .#zesh
./result/bin/zesh --help
```

---

#### Task 1.3: Add zesh devShell

**File:** `flake.nix`

**Changes:** Add to `devShells` section:
```nix
devShells.${system} = {
  # ... existing shells ...

  # Rust development for zesh
  zesh = pkgs.mkShell {
    buildInputs = with pkgs; [
      # Rust toolchain
      rustc
      cargo
      rust-analyzer
      clippy
      rustfmt

      # Build dependencies
      pkg-config
      openssl

      # Runtime deps for testing
      zellij
      fzf  # For comparison/fallback testing
    ];

    shellHook = ''
      echo "🎯 Zesh devShell loaded"
      echo "   Rust: $(rustc --version | cut -d' ' -f2)"
      echo "   Cargo: $(cargo --version | cut -d' ' -f2)"
      echo ""
    '';
  };
};
```

**Verification:**
```bash
cd apps/zesh
direnv allow
# Should see "Zesh devShell loaded"
cargo --version
```

---

#### Task 1.4: Wire overlay into NixOS/Home Manager

**File:** `flake.nix`

**Changes:** Update nixosConfigurations to use overlay:
```nix
nixosConfigurations = {
  devbox = nixpkgs.lib.nixosSystem {
    inherit system;
    specialArgs = { inherit inputs; };
    modules = [
      ./nixos/hosts/devbox/configuration.nix
      home-manager.nixosModules.home-manager
      {
        # Apply overlay so pkgs.zesh is available
        nixpkgs.overlays = [ zeshOverlay ];

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.cuiv = import ./home/users/cuiv/default.nix;
        };
      }
    ];
  };
};
```

**Verification:**
```bash
nix build .#nixosConfigurations.devbox.config.system.build.toplevel
# Should build without errors referencing zesh
```

---

### Phase 2: Rust Project Scaffolding

#### Task 2.1: Create Cargo project

**Commands:**
```bash
mkdir -p apps/zesh
cd apps/zesh
cargo init --name zesh
```

**File:** `apps/zesh/Cargo.toml`

```toml
[package]
name = "zesh"
version = "0.1.0"
edition = "2021"
description = "Fast terminal session manager for zellij"
authors = ["Peter Petrov <peter@petrovs.io>"]
license = "MIT"

[dependencies]
# CLI
clap = { version = "4", features = ["derive"] }

# Config
serde = { version = "1", features = ["derive"] }
toml = "0.8"

# Filesystem
ignore = "0.4"           # Fast directory walking (ripgrep's crate)
shellexpand = "3"        # ~/path expansion

# Picker
skim = "0.10"            # fzf clone in Rust

# Data
serde_json = "1"         # Frecency persistence

# Error handling
anyhow = "1"
thiserror = "2"

# Misc
dirs = "5"               # XDG paths
```

---

#### Task 2.2: Create .envrc

**File:** `apps/zesh/.envrc`

```bash
use flake ../.#zesh
```

---

#### Task 2.3: Create .gitignore

**File:** `apps/zesh/.gitignore`

```gitignore
/target
Cargo.lock
```

**Note:** We DO commit `Cargo.lock` for reproducibility. Remove from .gitignore after first successful build.

Actually, **keep Cargo.lock committed** for reproducible builds. Update .gitignore:

```gitignore
/target
```

---

#### Task 2.4: Create CLAUDE.md

**File:** `apps/zesh/CLAUDE.md`

```markdown
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
```

---

#### Task 2.5: Create minimal main.rs

**File:** `apps/zesh/src/main.rs`

```rust
use anyhow::Result;
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "zesh")]
#[command(about = "Fast terminal session manager for zellij")]
struct Cli {
    /// Fuzzy match query (optional)
    query: Option<String>,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// List active zellij sessions
    Ls,
    /// Kill a session
    Kill { name: String },
    /// Kill sessions for non-existent projects
    Clean,
    /// Open config in $EDITOR
    Config,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Some(Commands::Ls) => {
            println!("TODO: List sessions");
        }
        Some(Commands::Kill { name }) => {
            println!("TODO: Kill session: {}", name);
        }
        Some(Commands::Clean) => {
            println!("TODO: Clean orphaned sessions");
        }
        Some(Commands::Config) => {
            println!("TODO: Open config");
        }
        None => {
            // Main flow: discover projects, pick, switch
            if let Some(query) = cli.query {
                println!("TODO: Fuzzy match for: {}", query);
            } else {
                println!("TODO: Interactive picker");
            }
        }
    }

    Ok(())
}
```

---

#### Task 2.6: Verify build works

**Commands:**
```bash
cd apps/zesh
cargo build
cargo run -- --help
```

**Expected output:**
```
Fast terminal session manager for zellij

Usage: zesh [QUERY] [COMMAND]

Commands:
  ls      List active zellij sessions
  kill    Kill a session
  clean   Kill sessions for non-existent projects
  config  Open config in $EDITOR
  help    Print this message or the help of the given subcommand(s)

Arguments:
  [QUERY]  Fuzzy match query (optional)

Options:
  -h, --help  Print help
```

---

### Phase 3: Home Manager Integration

#### Task 3.1: Add zesh to user packages

**File:** `home/users/cuiv/tools.nix`

**Changes:**
```nix
{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Core utilities
    ripgrep
    fd
    tree
    jq
    htop

    # Nix development
    nixfmt-rfc-style
    nil

    # Session management
    zesh  # ADD THIS
  ];

  # ... rest of file unchanged
}
```

**Verification:**
```bash
# Rebuild NixOS config
nix build .#nixosConfigurations.devbox.config.system.build.toplevel

# Or apply directly on devbox
sudo nixos-rebuild switch --flake /path/to/infra#devbox

# Test
which zesh
zesh --help
```

---

### Phase 4: Core Implementation (per design doc)

#### Task 4.1: Config parsing (`config.rs`)

Implement:
- Load `~/.config/zesh/config.toml`
- Parse roots with depth and sparse_checkout flags
- Use `dirs` crate for XDG paths
- Use `shellexpand` for `~` expansion

#### Task 4.2: Project discovery (`discovery.rs`)

Implement per design doc "Discovery Rules":
- Walk roots with `ignore` crate
- Find `.git` directories
- Run `git worktree list` for worktrees
- Run `git sparse-checkout list` for sparse zones
- Build `Project` structs with proper naming

#### Task 4.3: Frecency tracking (`frecency.rs`)

Implement:
- JSON persistence at `~/.local/share/zesh/frecency.json`
- Score calculation: `frequency * recency_weight`
- Update on project selection

#### Task 4.4: Zellij backend (`zellij.rs`)

Implement:
- `zellij list-sessions` parsing
- Session creation with layout detection
- Session switching
- Session killing

#### Task 4.5: Interactive picker (`picker.rs`)

Implement:
- skim integration for fuzzy selection
- Context-aware ordering (same worktree zones first)
- Frecency-based sorting

---

### Phase 5: Polish

#### Task 5.1: Add pre-commit hooks

**File:** `.pre-commit-config.yaml` (update existing)

Add Rust hooks:
```yaml
  - repo: local
    hooks:
      - id: cargo-fmt
        name: cargo fmt
        entry: cargo fmt --manifest-path apps/zesh/Cargo.toml --
        language: system
        types: [rust]
        pass_filenames: false

      - id: cargo-clippy
        name: cargo clippy
        entry: cargo clippy --manifest-path apps/zesh/Cargo.toml -- -D warnings
        language: system
        types: [rust]
        pass_filenames: false
```

#### Task 5.2: Add shell alias

Once zesh works, add to `home/users/cuiv/shell.nix`:
```nix
shellAliases = {
  # ... existing aliases ...
  t = "zesh";  # For muscle memory
};
```

---

## Complete flake.nix After All Changes

For reference, here's the target `flake.nix` structure:

```nix
{
  description = "Personal infrastructure monorepo - NixOS and Home-Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, naersk, ... }@inputs:
  let
    system = "x86_64-linux";

    # Overlay that adds zesh package
    zeshOverlay = final: prev: {
      zesh = let
        naersk' = prev.callPackage naersk {};
      in naersk'.buildPackage {
        src = ./apps/zesh;
        nativeBuildInputs = [ prev.pkg-config ];
        buildInputs = [ prev.openssl ];
      };
    };

    pkgs = import nixpkgs {
      inherit system;
      overlays = [ zeshOverlay ];
    };

    pkgsUnfree = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ zeshOverlay ];
    };
  in
  {
    nixosConfigurations = {
      devbox = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/hosts/devbox/configuration.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [ zeshOverlay ];
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.cuiv = import ./home/users/cuiv/default.nix;
            };
          }
        ];
      };
    };

    # Make zesh buildable standalone
    packages.${system}.zesh = pkgs.zesh;
    packages.${system}.default = pkgs.zesh;

    devShells.${system} = {
      default = pkgsUnfree.mkShell {
        buildInputs = with pkgsUnfree; [
          terraform ansible ansible-lint
          sops age
          deadnix statix nixfmt-rfc-style nil
          jq yq-go shellcheck pre-commit
          trufflehog gitleaks
        ];
        shellHook = ''
          echo "🏗️  Infra devShell loaded"
          echo "   Terraform: $(terraform version -json | jq -r '.terraform_version')"
          echo "   Ansible:   $(ansible --version | head -1)"
          echo ""
        '';
      };

      media-pipeline = pkgs.mkShell {
        buildInputs = with pkgs; [ go gopls gotools go-tools ];
        shellHook = ''
          echo "🎬 Media Pipeline devShell loaded"
          echo "   Go: $(go version | cut -d' ' -f3)"
          echo ""
        '';
      };

      session-manager = pkgs.mkShell {
        buildInputs = with pkgs; [ bash shellcheck shfmt ];
        shellHook = ''
          echo "📺 Session Manager devShell loaded"
          echo ""
        '';
      };

      zesh = pkgs.mkShell {
        buildInputs = with pkgs; [
          rustc cargo rust-analyzer clippy rustfmt
          pkg-config openssl
          zellij fzf
        ];
        shellHook = ''
          echo "🎯 Zesh devShell loaded"
          echo "   Rust: $(rustc --version | cut -d' ' -f2)"
          echo "   Cargo: $(cargo --version | cut -d' ' -f2)"
          echo ""
        '';
      };
    };
  };
}
```

---

## Verification Checklist

After implementation, verify:

- [ ] `nix flake check` passes
- [ ] `nix build .#zesh` produces binary
- [ ] `./result/bin/zesh --help` works
- [ ] `cd apps/zesh && direnv allow` loads Rust toolchain
- [ ] `cargo build` works in apps/zesh
- [ ] `cargo test` passes
- [ ] `cargo clippy -- -D warnings` passes
- [ ] `cargo fmt --check` passes
- [ ] NixOS rebuild works with zesh in packages
- [ ] `zesh --help` works on devbox after rebuild

---

## Migration Path

1. Build zesh alongside existing `t` script
2. Test zesh manually for a week
3. Add `t = "zesh"` alias once confident
4. Remove `apps/session-manager/t` script
5. Clean up dotfiles stow package (remove old `t` symlink)

---

## References

- [naersk GitHub](https://github.com/nix-community/naersk)
- [NixOS Wiki - Rust](https://nixos.wiki/wiki/Rust)
- [NixOS & Flakes Book - Overlays](https://nixos-and-flakes.thiscute.world/nixpkgs/overlays)
- Design doc: `docs/plans/2025-12-26-zesh-session-manager-design.md`
