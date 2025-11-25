# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context Before Starting

**Always read these files first:**
- `docs/reference/current-state.md` - Complete infrastructure state (containers, IPs, hardware)
- `AGENTS.md` - Quick command reference and code conventions
- `notes/wip/CURRENT-STATUS.md` - Active work in progress (if exists)

This is a Proxmox homelab managed entirely as Infrastructure as Code using Terraform (container provisioning) and Ansible (configuration management), with a complete media processing pipeline.

## Infrastructure Commands

### Terraform Workflow
```bash
# From repository root
cd terraform
terraform init              # Initialize providers (first time or after provider changes)
terraform plan              # Preview changes
terraform apply             # Apply changes
terraform fmt -recursive    # Format all .tf files
terraform validate          # Validate configuration
```

**Key Details:**
- Providers: `bpg/proxmox` (~0.50.0), `tailscale/tailscale` (~0.16)
- Each container has its own `.tf` file (e.g., `ripper.tf`, `jellyfin.tf`)
- Variables in `variables.tf`, secrets in `terraform.tfvars` (gitignored)
- Never commit: `*.tfstate`, `*.tfstate.backup`, `terraform.tfvars`

### Ansible Workflow
```bash
# From repository root or ansible/ directory
ansible-playbook ansible/playbooks/site.yml --vault-password-file .vault_pass
ansible-playbook ansible/playbooks/<service>.yml --vault-password-file .vault_pass

# Dry-run with check mode
ansible-playbook ansible/playbooks/site.yml --check --vault-password-file .vault_pass

# Target specific tags
ansible-playbook ansible/playbooks/site.yml --tags common --vault-password-file .vault_pass

# Syntax validation
ansible-playbook ansible/playbooks/<playbook>.yml --syntax-check
```

**Inventory:** `ansible/inventory/hosts.yml` defines all hosts with IPs and container IDs

**Key Playbooks:**
- `site.yml` - Apply common role to all infrastructure
- `containers-base.yml` - Base setup for all containers
- Service-specific: `ripper.yml`, `jellyfin.yml`, `backup.yml`, `dns.yml`, `proxy.yml`, etc.

**Never commit:** `.vault_pass`, `**/secrets*.yml` (encrypted with Ansible Vault)

### Linting and Pre-commit
```bash
# Run all pre-commit hooks
pre-commit run --all-files

# Individual checks
shellcheck scripts/**/*.sh
terraform fmt -check -recursive terraform/
yamllint -c .yamllint.yaml .
cd ansible && ansible-lint --offline
```

## Media Pipeline Architecture

The media pipeline is a 4-stage process across 3 specialized containers:

```
Stage 1: Rip       → Stage 2: Remux    → Stage 3: Transcode → Stage 4: Organize
(ripper CT302)       (analyzer CT303)     (transcoder CT304)   (analyzer CT303)
    ↓                    ↓                      ↓                    ↓
1-ripped/            2-remuxed/            3-transcoded/         library/
```

**Storage:** All containers mount `/mnt/storage/media` (host) as `/mnt/media` (container)

**Scripts Location:** `scripts/media/production/` (deployed to `~/scripts/` on containers)

**Standard CLI:** All scripts use `-t <type> -n <name> [-s <season>]` format

### Running Media Scripts

Scripts must run as the `media` user (UID 1000):

```bash
# On the container directly
sudo -u media ./rip-disc.sh -t movie -n "The Matrix"
sudo -u media ./remux.sh -t show -n "Breaking Bad" -s 1
sudo -u media nohup ./transcode.sh -t show -n "Breaking Bad" -s 1 &
sudo -u media ./filebot.sh -t show -n "Breaking Bad" -s 1 --preview

# Remote execution from client (NOT from Proxmox host)
ssh media@ripper.home.arpa "./rip-disc.sh -t movie -n 'The Matrix'"
```

**Job Monitoring:**
```bash
ls ~/active-jobs/                    # List active jobs
cat ~/active-jobs/*/status           # Check job status
tail -f ~/active-jobs/*/transcode.log # Follow logs
```

Each script creates a hidden state directory (`.rip/`, `.remux/`, `.transcode/`, `.filebot/`) with status, logs, and metadata. Active jobs are symlinked to `~/active-jobs/` for visibility.

See `docs/reference/media-pipeline-quick-reference.md` for complete usage.

## Container Architecture

All containers are:
- **OS:** Debian 12 (Bookworm)
- **Type:** Privileged LXC containers
- **Provisioning:** Terraform (infrastructure)
- **Configuration:** Ansible (software and settings)

**Container Inventory:**

| CTID | Hostname   | IP          | Purpose                    | Special Hardware         |
|------|------------|-------------|----------------------------|--------------------------|
| 300  | backup     | 192.168.1.120 | Restic + Backrest UI      | -                        |
| 301  | samba      | 192.168.1.121 | SMB file shares           | -                        |
| 302  | ripper     | 192.168.1.131 | MakeMKV Blu-ray ripper    | Optical drive passthrough|
| 303  | analyzer   | 192.168.1.133 | FileBot + media tools     | -                        |
| 304  | transcoder | 192.168.1.132 | FFmpeg transcoding        | Intel Arc A380 GPU       |
| 305  | jellyfin   | 192.168.1.130 | Media server              | Intel Arc + NVIDIA GTX   |
| 310  | dns        | 192.168.1.110 | AdGuard Home (backup DNS) | -                        |
| 311  | proxy      | 192.168.1.111 | Caddy reverse proxy       | -                        |

**SSH Access:**
```bash
# Direct container access (preferred)
ssh media@ripper.home.arpa
ssh root@backup.home.arpa

# From Proxmox host
pct enter 302
```

**Testing:** Use CTID 199 for testing infrastructure changes before touching production containers.

## Critical Ansible Roles

Understanding these roles is key to making infrastructure changes:

- `common` - Base system (users, SSH keys, packages, sshd config)
- `intel_gpu_passthrough` / `dual_gpu_passthrough` - GPU configuration for hardware acceleration
- `optical_drive_passthrough` - Blu-ray drive access for ripper
- `makemkv` - Disc ripping software
- `media_analyzer` - FileBot and media analysis tools
- `jellyfin` - Media server configuration
- `restic_backup` - Automated backups to Backblaze B2
- `proxmox_storage` - MergerFS + SnapRAID storage pool
- `proxmox_host_setup` - Host maintenance (repos, kernel cleanup, unattended upgrades, fstrim)
- `proxmox_container_updates` - Automated container update scripts
- `adguard_home` - DNS with ad blocking
- `caddy` - Reverse proxy with automatic HTTPS
- `tailscale_subnet_router` - VPN subnet routing

## Code Conventions

**Terraform:**
- HCL format, 2 spaces
- One container per `.tf` file
- Use variables for reusable values
- Descriptive resource names (e.g., `proxmox_virtual_environment_container.ripper`)

**Ansible:**
- YAML format, 2 spaces
- Handlers in `handlers/main.yml`
- Tasks must be idempotent
- Use `--check` mode for dry-runs
- Encrypt secrets with `ansible-vault encrypt`

**Bash Scripts:**
- Include shebang `#!/bin/bash`
- Use `set -e` for error handling on critical operations
- Quote all variables: `"$VAR"`
- Absolute paths in production scripts
- Descriptive comments for non-obvious logic

**Naming:**
- Files/vars: `snake_case`
- Descriptive names (e.g., `backup.tf`, `ripper.yml`)
- Paths in docs: relative to repo root (`ansible/roles/...`)

**Git Commits:**
- Format: `<type>: <description>`
- Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`

## Storage Structure

**Proxmox Host:**
```
/mnt/storage/             # MergerFS pool (35TB, 4 disks)
├── media/
│   ├── staging/
│   │   ├── 1-ripped/    # Raw MakeMKV output
│   │   ├── 2-remuxed/   # Language-filtered remux
│   │   ├── 3-transcoded/# H.265 encoded files
│   │   └── 4-ready/     # (deprecated, use library/)
│   ├── library/         # Final organized media for Jellyfin
│   │   ├── movies/
│   │   └── tv/
│   ├── audiobooks/
│   └── e-books/
```

**Container Mount:** `/mnt/storage/media` → `/mnt/media` (bind mount in all media containers)

## Network Architecture

**Primary Network:** 192.168.1.0/24

**DNS:**
- Primary: Pi4 (192.168.1.102) - AdGuard Home + Tailscale subnet router
- Backup: CT310 (192.168.1.110) - AdGuard Home
- Local domain rewrites: `*.paniland.com`, `*.home.arpa`

**Remote Access (Tailscale):**
- Tailnet: `pigeon-piano.ts.net`
- Primary subnet router: Pi4 (192.168.1.102)
- Secondary: Proxmox host (192.168.1.100)
- Advertised routes: `192.168.1.0/24`
- ACLs managed via Terraform (`terraform/tailscale.tf`)

**Reverse Proxy (Caddy):**
- Host: CT311 (192.168.1.111)
- Automatic HTTPS via Cloudflare DNS-01 challenge
- Proxied services: jellyfin, backup, dns, proxmox

## Making Infrastructure Changes

**Process:**
1. Update Terraform config (if changing container specs/IDs)
2. Run `terraform plan` to preview
3. Apply with `terraform apply`
4. Update Ansible playbook/role (if changing software/config)
5. Test with `ansible-playbook <playbook>.yml --check`
6. Apply with `ansible-playbook <playbook>.yml --vault-password-file .vault_pass`
7. Update `docs/reference/current-state.md` if infrastructure state changed

**Testing First:**
- Use CTID 199 for testing new containers/configurations
- Use `--check` mode for Ansible dry-runs
- Always `terraform plan` before `apply`

## Hardware Passthrough Patterns

**GPU Passthrough (Intel Arc A380 to transcoder):**
- Managed by `intel_gpu_passthrough` role
- Device: `/dev/dri/renderD128`
- Verification: `vainfo` in container

**Dual GPU (Arc + NVIDIA to jellyfin):**
- Managed by `dual_gpu_passthrough` role
- Intel Arc for transcoding, NVIDIA for display/fallback
- Both `/dev/dri/*` devices passed through

**Optical Drive (to ripper):**
- Managed by `optical_drive_passthrough` role
- Devices: `/dev/sr0`, `/dev/sg4`
- Verification: `ls -la /dev/sr0` in container

## Common Development Tasks

**Add a new container:**
1. Create `terraform/<name>.tf` with container definition
2. Add to `ansible/inventory/hosts.yml` with IP and CTID
3. Create `ansible/playbooks/<name>.yml` playbook
4. Apply: `terraform apply` then `ansible-playbook ansible/playbooks/<name>.yml`
5. Update `docs/reference/current-state.md`

**Modify existing container configuration:**
1. Update relevant Ansible role in `ansible/roles/<role>/`
2. Test: `ansible-playbook ansible/playbooks/<service>.yml --check`
3. Apply: `ansible-playbook ansible/playbooks/<service>.yml --vault-password-file .vault_pass`

**Update media pipeline script:**
1. Edit script in `scripts/media/production/`
2. Test locally or on appropriate container
3. Redeploy via Ansible if needed (scripts synced via roles)
4. Update `docs/reference/media-pipeline-quick-reference.md` if CLI changed

## Security Notes

**Never commit:**
- Terraform state files (`*.tfstate`, `*.tfstate.backup`)
- Secrets files (`terraform.tfvars`, `.vault_pass`)
- Ansible vault files ending in `secrets.yml` (committed encrypted only)
- API tokens, passwords, credentials

**Secrets Management:**
- Terraform: Use `terraform.tfvars` (gitignored)
- Ansible: Encrypt with `ansible-vault encrypt ansible/vars/<name>_secrets.yml`
- Decrypt: `ansible-vault view ansible/vars/<name>_secrets.yml --vault-password-file .vault_pass`

## Documentation Structure

```
docs/
├── guides/          # Step-by-step how-to guides (setup, workflows)
├── reference/       # Quick references and current state
├── plans/           # Planning workflow
│   ├── ideas/      # Brainstorming and early concepts
│   ├── active/     # Current implementation plans (rarely used)
│   └── archive/    # Completed implementations
└── archive/         # Obsolete documentation
```

**Key Documents:**
- `docs/reference/current-state.md` - System configuration (MUST update after infrastructure changes)
- `docs/reference/media-pipeline-quick-reference.md` - Media script commands
- `docs/guides/ripping-workflow-*.md` - Complete workflows for movies/TV

## Automated Maintenance

The infrastructure includes several automated maintenance tasks:

- **Weekly:** Container updates (Sun 3AM), Host backup (Sun 2AM), FSTRIM (Sat 11PM)
- **Daily:** Restic backup to Backblaze B2 (2AM)
- **Retention:** 7 daily, 4 weekly, 6 monthly, 2 yearly

These are configured via:
- `proxmox_container_updates` role (container update scripts)
- `proxmox_host_backup` role (host backup scripts)
- `restic_backup` role (systemd timers)
- `proxmox_host_setup` role (fstrim timer)
