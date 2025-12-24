# Infra

Personal infrastructure monorepo - homelab, dotfiles, and NixOS configurations.

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![NixOS](https://img.shields.io/badge/NixOS-5277C3?style=flat&logo=nixos&logoColor=white)
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=flat&logo=proxmox&logoColor=white)

## Structure

```
apps/          # Personal applications (media-pipeline, session-manager)
terraform/     # Proxmox containers, Tailscale ACLs
ansible/       # Debian container configuration
nixos/         # NixOS system configurations (flake-based)
home/          # Home-Manager user configurations
dotfiles/      # Personal dotfiles (stow-managed)
docs/          # Guides and reference
scripts/       # Operational scripts
```

## Quick Start

```bash
# Clone
git clone git@github.com:cuivienor/infra.git ~/dev/infra

# Enter devShell (terraform, ansible, sops, etc.)
cd ~/dev/infra
direnv allow  # or: nix develop

# Infrastructure changes
cd terraform/proxmox-homelab && terraform apply

# Configuration changes
cd ansible && ansible-playbook playbooks/<service>.yml

# NixOS changes (on devbox)
sudo nixos-rebuild switch --flake .#devbox
```

## Dotfiles

See [dotfiles/README.md](dotfiles/README.md) for setup instructions (symlink or sparse checkout).

## Documentation

- [Current State](docs/reference/current-state.md) - Infrastructure overview
- [CLAUDE.md](CLAUDE.md) - Development conventions
