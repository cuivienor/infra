# Homelab Infrastructure & Media Pipeline

This repository contains Infrastructure as Code, automation scripts, and documentation for my homelab setup.

## Quick Links

- **[Organization Guide](ORGANIZATION.md)** - How this repo is structured
- **[IaC Strategy](docs/reference/homelab-iac-strategy.md)** - Terraform & Ansible plan
- **[Media Pipeline Guide](docs/guides/media-pipeline-v2.md)** - Media workflow documentation

## Repository Structure

```
├── terraform/          # Infrastructure as Code (Proxmox containers)
├── ansible/           # Configuration management (playbooks & roles)
├── scripts/           # Operational scripts
│   ├── media/        # Media pipeline automation
│   ├── iac/          # Infrastructure helpers
│   └── utils/        # Utilities
├── docs/             # Formal documentation
│   ├── guides/       # How-to guides
│   ├── reference/    # Quick references
│   ├── plans/        # Planning documents
│   └── archive/      # Completed/obsolete docs
└── notes/            # Working notes and WIP
```

## Getting Started

### Media Pipeline Scripts

All media processing scripts are in `scripts/media/`:
- `rip-disc.sh` - Rip Blu-ray discs with MakeMKV
- `transcode-media.sh` - Transcode videos with hardware acceleration
- `organize-media.sh` - Organize media files with FileBot

See [Media Pipeline Quick Reference](docs/reference/media-pipeline-quick-reference.md) for details.

### Infrastructure as Code

Terraform and Ansible configurations for managing Proxmox containers:
- See [IaC Strategy](docs/reference/homelab-iac-strategy.md) for the plan
- `terraform/` - Container definitions
- `ansible/` - Configuration playbooks

## Contributing

This is a personal homelab repo, but feel free to fork and adapt for your own use!
