# Homelab

Infrastructure as Code for my Proxmox homelab.

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?style=flat&logo=proxmox&logoColor=white)
![Tailscale](https://img.shields.io/badge/Tailscale-242424?style=flat&logo=tailscale&logoColor=white)
![Backblaze](https://img.shields.io/badge/Backblaze_B2-E21E29?style=flat&logo=backblaze&logoColor=white)

## Stack

- **Terraform** - Container provisioning (Proxmox, Tailscale)
- **Ansible** - Configuration management
- **Proxmox VE** - Hypervisor running Debian LXC containers
- **Tailscale** - Remote access with subnet routing
- **Backblaze B2** - Off-site backups via Restic

## Services

| Service | Description |
|---------|-------------|
| [Jellyfin](https://jellyfin.org/) | Media server |
| [AdGuard Home](https://adguard.com/adguard-home.html) | DNS with ad blocking |
| [Caddy](https://caddyserver.com/) | Reverse proxy |
| [Backrest](https://github.com/garethgeorge/backrest) | Restic backup UI |
| [Wishlist](https://github.com/cmintey/wishlist) | Gift registry |
| [MakeMKV](https://www.makemkv.com/) | Blu-ray ripper |
| [FileBot](https://www.filebot.net/) | Media organizer |

## Structure

```
terraform/     # Infrastructure definitions
ansible/       # Playbooks and roles
scripts/       # Operational scripts
docs/          # Guides and reference
```

## Usage

```bash
# Infrastructure changes
cd terraform && terraform plan && terraform apply

# Configuration changes
cd ansible && ansible-playbook playbooks/<service>.yml
```

## Documentation

- [Current State](docs/reference/current-state.md) - Infrastructure overview
- [CLAUDE.md](CLAUDE.md) - AI agent context and conventions
