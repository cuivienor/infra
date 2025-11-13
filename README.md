# Homelab Infrastructure & Media Pipeline

This repository contains Infrastructure as Code, automation scripts, and documentation for my homelab media processing setup.

## Repository Structure

```
├── terraform/          # Infrastructure as Code (Proxmox containers)
├── ansible/           # Configuration management (playbooks & roles)
├── scripts/           # Operational scripts
│   ├── media/        # Media pipeline automation (production/archive/migration/utilities)
│   └── utils/        # General utilities
├── docs/             # Formal documentation
│   ├── containers/   # Container operational docs
│   ├── guides/       # How-to guides
│   ├── reference/    # Quick references and strategy docs
│   ├── plans/        # Planning workflow (ideas → active → archive)
│   └── archive/      # Completed/obsolete docs
└── notes/            # Working notes and WIP status
```

## Quick Start

### Infrastructure Management

All infrastructure is managed as code using Terraform and Ansible:

```bash
# Deploy infrastructure
cd terraform && terraform plan
cd ansible && ansible-playbook site.yml
```

See **[IaC Strategy](docs/reference/homelab-iac-strategy.md)** for complete details.

### Media Pipeline

Media processing scripts are organized in `scripts/media/production/`:

```bash
# Rip Blu-ray disc
sudo -u media scripts/media/production/rip-disc.sh

# Transcode with hardware acceleration
sudo -u media scripts/media/production/transcode-queue.sh

# Organize and remux media files
sudo -u media scripts/media/production/organize-and-remux-movie.sh
sudo -u media scripts/media/production/organize-and-remux-tv.sh
```

See **[Media Pipeline Guide](docs/guides/media-pipeline-v2.md)** for workflow details.

## Container Inventory

All containers use Terraform for provisioning and Ansible for configuration:

| CTID | Name | IP (DHCP) | Purpose | Docs |
|------|------|-----------|---------|------|
| 300 | backup | 192.168.1.58 | Restic backup server | [ct300-backup.md](docs/containers/ct300-backup.md) |
| 301 | samba | 192.168.1.82 | Samba file server | [ct301-samba.md](docs/containers/ct301-samba.md) |
| 302 | ripper | 192.168.1.70 | MakeMKV Blu-ray ripper | [ct302-ripper.md](docs/containers/ct302-ripper.md) |
| 303 | analyzer | 192.168.1.73 | Media analyzer | [ct303-analyzer.md](docs/containers/ct303-analyzer.md) |
| 304 | transcoder | DHCP | FFmpeg transcoder (Intel GPU) | [ct304-transcoder.md](docs/containers/ct304-transcoder.md) |
| 305 | jellyfin | 192.168.1.85 | Media server (dual GPU) | [ct305-jellyfin.md](docs/containers/ct305-jellyfin.md) |

## Key Documentation

### Essential Reads
- **[AGENTS.md](AGENTS.md)** - AI context and conventions for working with this repo
- **[Hardware Inventory](docs/reference/hardware-inventory.md)** - Complete system specs
- **[Current State](docs/reference/current-state.md)** - System configuration details
- **[Media Pipeline Quick Reference](docs/reference/media-pipeline-quick-reference.md)** - Common commands

### How-To Guides
- [Media Pipeline v2 Workflow](docs/guides/media-pipeline-v2.md)
- [Jellyfin Setup](docs/guides/jellyfin-setup.md)
- [Transcoding Container Setup](docs/guides/transcoding-container-setup.md)
- [Backup Setup](docs/guides/backup-setup.md)

## Planning Workflow

This repository uses a structured planning workflow in `docs/plans/`:

- **`ideas/`** - Brainstorming and early concepts
- **`active/`** - Current/upcoming implementation plans
- **`archive/`** - Completed implementations (for reference)

See [docs/plans/README.md](docs/plans/README.md) for details on the planning process.

## Infrastructure Overview

### Host System
- **Platform**: Proxmox VE 8.4.14
- **CPU**: Intel i5-9600K (6 cores)
- **RAM**: 32GB
- **Storage**: 35TB MergerFS pool (SnapRAID parity)
- **GPUs**: Intel Arc A380 (transcoding) + NVIDIA GTX 1080 (display)

### Storage Structure
```
/mnt/storage/media/
├── staging/          # Media pipeline staging
│   ├── 0-raw/       # Raw MakeMKV output
│   ├── 1-ripped/    # Transcoded files
│   └── 2-ready/     # Organized, ready to move
├── movies/          # Movie library
├── tv/              # TV show library
├── audiobooks/
└── e-books/
```

## SSH Access

```bash
# Proxmox host
ssh homelab        # 192.168.1.56

# Container access (from host)
pct enter <CTID>

# Direct SSH (if enabled)
ssh root@<container-ip>
```

## Git Workflow

Never commit secrets or state files. Check `.gitignore` for excluded patterns.

```bash
# Standard workflow
git status
git add <files>
git commit -m "type: description"
git push
```

Commit types: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`

## Working with IaC

### Never Commit
- Terraform state files (`*.tfstate`)
- Variable files with secrets (`terraform.tfvars`)
- Ansible vault passwords (`.vault_pass`)
- API tokens or credentials

### Always Commit
- Terraform configurations (`*.tf`)
- Ansible playbooks and roles
- IaC helper scripts
- Documentation

## Contributing

This is a personal homelab repo, but feel free to fork and adapt for your own use!
