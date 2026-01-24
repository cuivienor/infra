# CLAUDE.md

Proxmox homelab infrastructure monorepo. Terraform provisions, Ansible configures, Nix manages dev environment.

**Generated:** 2026-01-07 | **Commit:** 17b6c11 | **Branch:** main

## OVERVIEW

Infrastructure as Code for personal homelab: 12 LXC containers on Proxmox, managed via Terraform (provisioning) + Ansible (configuration). Includes Go/Rust apps, NixOS configs, and dotfiles.

## STRUCTURE

```
infra/
├── terraform/           # Container provisioning (4 root modules)
│   ├── proxmox-homelab/ # LXC containers - MOST COMMON
│   ├── tailscale/       # VPN ACLs, DNS
│   ├── cloudflare/      # DNS records, tunnels
│   └── lldap/           # LDAP user management
├── ansible/             # Service configuration
│   ├── playbooks/       # Entry points (22 playbooks)
│   └── roles/           # Reusable modules (15+ roles)
├── home/                # Home Manager (user environment)
├── nixos/               # NixOS system configs (devbox)
├── apps/
│   ├── media-pipeline/  # Go TUI for media ripping
│   └── zesh/            # Rust session manager
├── dotfiles/            # GNU Stow packages
├── images/              # Nix LXC template builds
└── docs/                # Plans, reference, ideas
```

## DEVSHELL (CRITICAL)

**All commands require the Nix devshell.** Tools like `terraform`, `ansible`, `sops` are NOT installed system-wide.

### Verify DevShell is Active

```bash
which terraform  # Should show /nix/store/... path
```

If you see "command not found", the devshell isn't loaded.

### Load DevShell

```bash
direnv allow    # First time only - trusts .envrc
# DevShell loads automatically when entering directory
# You'll see: "🏗️ Infra devShell loaded (unified)"
```

### Common Errors (DevShell Not Loaded)

| Error | Cause |
|-------|-------|
| `terraform: command not found` | DevShell not loaded |
| `ansible: command not found` | DevShell not loaded |
| `sops: command not found` | DevShell not loaded |
| `Error decrypting` | Missing secrets - run `infra-setup-secrets` |

### First-Time Secrets Setup

```bash
export BW_SESSION=$(bw unlock --raw)
infra-setup-secrets    # Restores .sops-key and .vault_pass from Bitwarden
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Create/modify containers | `terraform/proxmox-homelab/` | One `.tf` per container |
| Install/configure software | `ansible/playbooks/<service>.yml` | Run from `ansible/` dir |
| VPN ACLs, DNS split | `terraform/tailscale/` | Separate state file |
| Dev environment tools | `flake.nix` → devShells | Single unified shell |
| User shell/tools config | `home/users/cuiv/` | Modular nix files |
| Media pipeline work | `apps/media-pipeline/` | Go + Bubbletea TUI |
| Zellij session manager | `apps/zesh/` | Rust + skim picker |
| Personal dotfiles | `dotfiles/stow/` | Per-app packages |

## IaC DISCIPLINE (CRITICAL)

**All changes through Terraform or Ansible. SSH = read-only debugging.**

| Change | Tool | Never Do |
|--------|------|----------|
| Container specs | Terraform | `pct set` via SSH |
| Packages, config | Ansible | `apt install` via SSH |
| Services | Ansible | `systemctl` via SSH |
| NixOS (devbox) | `nixos-rebuild switch` | Manual edits |

## CONTAINERS

| CTID | Host | IP | Purpose |
|------|------|-----|---------|
| 300 | backup | .120 | Restic → Backblaze B2 |
| 301 | samba | .121 | SMB shares |
| 302 | ripper | .131 | MakeMKV (optical drive) |
| 303 | analyzer | .133 | FileBot, media tools |
| 304 | transcoder | .132 | FFmpeg (Intel Arc GPU) |
| 305 | jellyfin | .130 | Media server (dual GPU) |
| 307 | wishlist | .186 | Gift registry (Node.js) |
| 308 | lldap | .114 | LDAP directory |
| 310 | dns | .110 | AdGuard Home (backup) |
| 311 | proxy | .111 | Caddy reverse proxy |
| 312 | authelia | .112 | SSO (OIDC) |
| 320 | devbox | .140 | NixOS dev environment |

**SSH:** `ssh ripper`, `ssh jellyfin`, etc. (aliases in `~/.ssh/config`)

## SECRETS

| Type | Location | Edit |
|------|----------|------|
| Terraform | `terraform/*/secrets.sops.yaml` | `sops <file>` |
| Ansible | `ansible/vars/*_secrets.yml` | `ansible-vault edit <file>` |

Keys: `terraform/.sops-key`, `ansible/.vault_pass` (gitignored → Bitwarden)

## COMMANDS

```bash
# Development
direnv allow                              # Load Nix devShell
nix develop                               # Manual shell entry

# Infrastructure
cd terraform/proxmox-homelab && terraform plan && terraform apply
cd ansible && ansible-playbook playbooks/<service>.yml --check  # Dry run
cd ansible && ansible-playbook playbooks/<service>.yml          # Apply

# NixOS (on devbox)
sudo nixos-rebuild switch --flake .#devbox

# Apps
cd apps/media-pipeline && make test && make build
cd apps/zesh && cargo test && cargo build
```

## CONVENTIONS

- **Commits:** `<type>: <description>` (feat, fix, docs, refactor, chore)
- **Files:** `snake_case`
- **Pre-commit:** Always runs. Never skip hooks.
- **Ansible:** FQCN required (`ansible.builtin.apt` not `apt`)
- **Go:** Standard fmt/vet. Table-driven tests.
- **Rust:** `cargo clippy -- -D warnings` must pass

## ANTI-PATTERNS (THIS PROJECT)

- `apt`, `systemctl`, file edits via SSH → Use IaC
- `terraform.tfvars` in git → Contains secrets
- State file manual edits → Work with Peter to fix
- Skipping pre-commit hooks → Never
- Plaintext secrets anywhere → SOPS or Vault only

## ZONE NAVIGATION

Each zone has CLAUDE.md with specific guidance:

| Zone | Read When |
|------|-----------|
| `terraform/CLAUDE.md` | Provisioning containers, ACLs |
| `ansible/CLAUDE.md` | Configuring services, roles |
| `home/CLAUDE.md` | Home Manager, zellij, shell |
| `apps/media-pipeline/CLAUDE.md` | Go TUI development |
| `apps/zesh/CLAUDE.md` | Rust session manager |
| `dotfiles/CLAUDE.md` | Stow packages |

**Skills:** `.claude/skills/` for workflows (homelab-iac, infra-nix, Rust)
