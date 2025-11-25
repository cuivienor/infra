# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context Before Starting

**Always read these files first:**
- `docs/reference/current-state.md` - Complete infrastructure state (containers, IPs, hardware)
- `notes/wip/CURRENT-STATUS.md` - Active work in progress (if exists)

This is a Proxmox homelab managed entirely as Infrastructure as Code using Terraform (container provisioning) and Ansible (configuration management), with a complete media processing pipeline.

## IaC Discipline (CRITICAL)

**This infrastructure is 100% IaC. All changes MUST go through Terraform or Ansible.**

### SSH is for Debugging Only

SSH access to containers and hosts is **read-only for debugging purposes**. You may:
- Run diagnostic commands (`systemctl status`, `journalctl`, `ls`, `cat`, `df`, `vainfo`, etc.)
- Check logs and service state
- Verify configuration was applied correctly
- Test connectivity and hardware access

You must **NEVER** run mutating commands via SSH:
- ❌ `apt install/remove/update`
- ❌ `systemctl enable/disable/start/stop`
- ❌ Creating/editing files
- ❌ Changing permissions or ownership
- ❌ Any `sudo` command that modifies state

### When You Need to Change Something

1. **Container specs** (CPU, memory, disk, network) → Update Terraform, run `terraform apply`
2. **Software/packages** → Update Ansible role, run the playbook
3. **Configuration files** → Update Ansible templates/files, run the playbook
4. **Services** → Update Ansible handlers, run the playbook
5. **Users/permissions** → Update Ansible role, run the playbook

**If you find yourself wanting to "just quickly fix" something via SSH, STOP.** Update the IaC instead. The only exception is one-time debugging during active troubleshooting sessions where you'll immediately codify the fix in Ansible afterward.

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
# ALWAYS run from the ansible/ directory
cd ansible

# Run a playbook (vault password auto-loaded from ansible.cfg)
ansible-playbook playbooks/site.yml
ansible-playbook playbooks/<service>.yml

# Dry-run with check mode
ansible-playbook playbooks/site.yml --check

# Target specific tags
ansible-playbook playbooks/site.yml --tags common

# Syntax validation
ansible-playbook playbooks/<playbook>.yml --syntax-check
```

**Long-Running Playbooks:** Some playbooks (especially `jellyfin.yml`, `transcoder.yml`, `proxmox-host.yml`) can take 5-10+ minutes due to package installations or compilations. When running these, use a 600000ms (10 minute) timeout for the Bash command. Don't assume failure if output is slow - wait for completion.

**Inventory:** `ansible/inventory/hosts.yml` defines all hosts with IPs and container IDs

**Key Playbooks:**
- `site.yml` - Apply common role to all infrastructure
- `containers-base.yml` - Base setup for all containers
- Service-specific: `ripper.yml`, `jellyfin.yml`, `backup.yml`, `dns.yml`, `proxy.yml`, etc.

**Never commit:** `ansible/.vault_pass`, `**/secrets*.yml` (encrypted with Ansible Vault)

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

**SSH Access (use aliases from ~/.ssh/config):**
```bash
# Infrastructure containers (connects as root)
ssh backup                    # backup.home.arpa
ssh dns                       # dns.home.arpa
ssh proxy                     # proxy.home.arpa
ssh jellyfin                  # jellyfin.home.arpa

# Media containers - default is media user
ssh ripper                    # ripper.home.arpa as media
ssh transcoder                # transcoder.home.arpa as media
ssh analyzer                  # analyzer.home.arpa as media

# Media containers - root access for maintenance
ssh ripper-root               # ripper.home.arpa as root
ssh transcoder-root           # transcoder.home.arpa as root
ssh analyzer-root             # analyzer.home.arpa as root

# Proxmox host
ssh homelab                   # homelab.home.arpa as cuiv
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
- Ansible: Encrypt with `ansible-vault encrypt vars/<name>_secrets.yml` (from ansible/ directory)
- Decrypt: `ansible-vault view vars/<name>_secrets.yml` (vault password auto-loaded from ansible.cfg)

## Documentation Structure

```
docs/
├── guides/          # Step-by-step how-to guides (setup, workflows)
├── reference/       # Quick references and current state
├── ideas/           # Future plans and brainstorming
└── archive/         # Completed implementations
```

**Key Documents:**
- `docs/reference/current-state.md` - System configuration (MUST update after infrastructure changes)
- `docs/reference/media-pipeline-quick-reference.md` - Media pipeline scripts, job monitoring, and workflows
- `docs/guides/ripping-workflow-*.md` - Step-by-step guides for movies/TV ripping

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
