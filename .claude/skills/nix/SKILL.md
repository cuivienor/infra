---
name: infra-nix
description: Use when working with Nix in the infra monorepo - devShells, devbox NixOS container, and Home-Manager user config.
---

# Infra Nix Patterns

## Overview

This repo uses Nix for development environments and the devbox container. See the global `nix` skill for general Nix knowledge.

## DevShells

This repo has a **single unified devShell** that provides all tools.

| Shell | Purpose | Enter |
|-------|---------|-------|
| default | All tools (Terraform, Ansible, Go, Rust, Python, etc.) | `direnv allow` (auto) or `nix develop` |

### Verify DevShell is Active

```bash
# Check for Nix store path
which terraform
# Expected: /nix/store/.../bin/terraform

# Or check environment
echo $IN_NIX_SHELL
# Expected: "impure" or "pure"
```

### Troubleshooting

| Symptom | Solution |
|---------|----------|
| `command not found` for terraform/ansible/sops | Run `direnv allow` or `nix develop` |
| `direnv: error .envrc` | Run `direnv allow` to trust the file |
| SOPS decryption fails | Run `infra-setup-secrets` after `bw unlock` |
| Ansible vault errors | Run `infra-setup-secrets` after `bw unlock` |

### Secrets Setup (First Time)

The devshell includes `infra-setup-secrets` to restore encryption keys:

```bash
bw login                              # If not logged in
export BW_SESSION=$(bw unlock --raw)  # Unlock vault
infra-setup-secrets                   # Restores keys from Bitwarden
```

This creates:
- `terraform/.sops-key` - Age key for SOPS encryption
- `ansible/.vault_pass` - Ansible vault password

### Add Package to DevShell

Edit `flake.nix`, find the relevant shell:

```nix
default = pkgsUnfree.mkShell {
  buildInputs = with pkgsUnfree; [
    # existing...
    newpackage  # Add here
  ];
};
```

Then: `direnv reload` or re-enter shell.

**Note:** Use `pkgsUnfree` for unfree packages (terraform), `pkgs` for everything else.

## Devbox Container

The only NixOS host. Runs in Proxmox LXC (CTID 320, IP .140).

### Key Files

```
flake.nix                              # Flake entry point
nixos/hosts/devbox/configuration.nix   # System config
home/users/cuiv/                       # Home-Manager config
  ├── default.nix                      # Main user config
  ├── git.nix                          # Git configuration
  ├── tools.nix                        # CLI tools
  └── shell.nix                        # Shell configuration
```

### Rebuild

From within devbox (SSH first):

```bash
ssh devbox
cd /path/to/infra

# Build and switch
sudo nixos-rebuild switch --flake .#devbox

# Build only (test)
nixos-rebuild build --flake .#devbox

# Rollback if broken
sudo nixos-rebuild switch --rollback
```

### Add System Package

Edit `nixos/hosts/devbox/configuration.nix`:

```nix
environment.systemPackages = with pkgs; [
  # existing...
  newpackage
];
```

### Add User Package

Edit `home/users/cuiv/tools.nix` (or create new module):

```nix
home.packages = with pkgs; [
  newpackage
];
```

## Workflow

1. Make changes to flake.nix or NixOS/Home-Manager configs
2. Format: `nix fmt` (uses nixfmt-rfc-style)
3. Check: `nix flake check`
4. If devShell change: `direnv reload`
5. If devbox change: SSH to devbox, run rebuild
6. Commit both `flake.nix` and `flake.lock`

## Never Do

- Edit `flake.lock` manually
- Change `system.stateVersion` or `home.stateVersion`
- Commit flake.nix without testing the change first
- Delete all old generations before verifying new config works
