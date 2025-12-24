# CLAUDE.md

Guidance for Claude Code working in this infrastructure monorepo.

## Context Before Starting

**Read first:** `docs/reference/current-state.md` - Complete infrastructure state (containers, IPs, hardware)

This is a Proxmox homelab managed as Infrastructure as Code using Terraform (provisioning) and Ansible (configuration).

## Development Environment

### With Nix (Recommended)

```bash
direnv allow                      # Auto-load default shell
nix develop .#media-pipeline      # Go toolchain
nix develop .#session-manager     # Bash/shellcheck
```

### Without Nix

```bash
./scripts/setup-dev.sh            # Install terraform, ansible, sops, etc.
```

## Zone Navigation

Each zone has its own CLAUDE.md with zone-specific guidance:

| Zone | When to Read |
|------|--------------|
| `terraform/` | Provisioning containers, Tailscale ACLs |
| `ansible/` | Configuring software, roles, playbooks |
| `nixos/` | Flake.nix, NixOS, Home-Manager |
| `apps/media-pipeline/` | Go media pipeline TUI |
| `apps/session-manager/` | Tmux sessionizer script |
| `dotfiles/` | Stow packages, dotfiles |

**Skills:** See `.claude/skills/` for workflow checklists (terraform-workflow, ansible-workflow, nix-development).

## IaC Discipline (CRITICAL)

**All changes MUST go through Terraform or Ansible. SSH is read-only for debugging.**

| Change Type | Tool |
|-------------|------|
| Container specs (CPU, memory, disk) | Terraform |
| Software, packages, config files | Ansible |
| Services, users, permissions | Ansible |

**Never** run `apt`, `systemctl`, or edit files via SSH. Update IaC instead.

## Quick Reference

### Containers

| CTID | Host | IP | Purpose |
|------|------|-----|---------|
| 300 | backup | .120 | Restic backups |
| 301 | samba | .121 | SMB shares |
| 302 | ripper | .131 | MakeMKV (optical drive) |
| 303 | analyzer | .133 | FileBot, media tools |
| 304 | transcoder | .132 | FFmpeg (Intel Arc GPU) |
| 305 | jellyfin | .130 | Media server (dual GPU) |
| 310 | dns | .110 | AdGuard Home |
| 311 | proxy | .111 | Caddy reverse proxy |
| 320 | devbox | .140 | NixOS dev environment |

**SSH:** Use aliases from `~/.ssh/config` (e.g., `ssh ripper`, `ssh jellyfin`).

### Secrets

| Type | Location | Edit Command |
|------|----------|--------------|
| Terraform | `terraform/*/secrets.sops.yaml` | `sops <file>` |
| Ansible | `ansible/vars/*_secrets.yml` | `ansible-vault edit <file>` |

Keys: `terraform/.sops-key`, `ansible/.vault_pass` (gitignored, restore from Bitwarden)

## Conventions

- **Commits:** `<type>: <description>` (feat, fix, docs, refactor, chore)
- **Files:** `snake_case`
- **Pre-commit:** Always runs - don't skip hooks
