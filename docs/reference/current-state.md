# Homelab Current State

**Last Updated**: 2025-11-16  
**Status**: Full Infrastructure as Code (Terraform + Ansible)  
**Remote Access**: Tailscale subnet routing with redundant routers

---

## Infrastructure Overview

### Physical Hardware

**Proxmox Host** (`homelab` - 192.168.1.100)
- CPU: Intel Core i5-9600K @ 3.70GHz (6 cores)
- RAM: 32 GB
- Storage: 1.7 TB local-lvm + 35TB MergerFS pool
- GPUs: Intel Arc A380 (transcoding), NVIDIA GTX 1080 (secondary)
- Optical: Blu-ray drive (`/dev/sr0`, `/dev/sg4`)

**Raspberry Pis**
- Pi4 (192.168.1.102) - Primary DNS + Tailscale subnet router
- Pi3 (192.168.1.101) - Available

### Storage Pool

**MergerFS** at `/mnt/storage` (35TB total, 14% used)
- disk1: 9.1T WD Red Plus (4.1T used)
- disk2: 9.1T Seagate Barracuda
- disk3: 17T WD Red Plus
- parity: 17T WD Red Plus (SnapRAID)

Policy: `eppfrd` (distribute to disk with most free space)

---

## Container Inventory

| CTID | Name | IP | Purpose |
|------|------|-----|---------|
| 300 | backup | .120 | Restic backups + Backrest UI |
| 301 | samba | .121 | SMB file shares |
| 302 | ripper | .131 | MakeMKV (optical drive passthrough) |
| 303 | analyzer | .133 | FileBot + media tools |
| 304 | transcoder | .132 | FFmpeg (Intel Arc GPU passthrough) |
| 305 | jellyfin | .130 | Media server (dual GPU passthrough) |
| 307 | wishlist | .186 | Self-hosted gift registry (Node.js) |
| 310 | dns | .110 | Backup DNS (AdGuard Home) |
| 311 | proxy | .111 | Caddy reverse proxy (HTTPS) |

All containers: Debian 12, privileged, IaC-managed via Terraform + Ansible

---

## Network Services

### DNS (AdGuard Home)
- **Primary**: Pi4 (192.168.1.102:53)
- **Backup**: CT310 (192.168.1.110:53)
- Ad blocking: HaGeZi Pro blocklist
- Local rewrites for `*.paniland.com`

### Reverse Proxy (Caddy)
- **Host**: CT311 (192.168.1.111)
- Automatic HTTPS via Cloudflare DNS-01
- Proxied services: jellyfin, backup, dns, proxmox

### Remote Access (Tailscale)
- **Tailnet**: pigeon-piano.ts.net
- **Subnet Routers**: Pi4 (primary), Proxmox (secondary)
- **Routes**: 192.168.1.0/24
- **DNS**: Split DNS for `*.paniland.com` and `*.home.arpa`
- **ACLs**: Admins (full access), Friends (Jellyfin only)

---

## Infrastructure as Code

### Terraform (`terraform/`)
- Proxmox containers (BPG provider ~0.50.0)
- Tailscale ACLs, DNS, auth keys (~0.16)
- All container definitions in separate `.tf` files

### Ansible (`ansible/`)
Key roles:
- `common` - Base system config
- `adguard_home` - DNS with ad blocking
- `caddy` - Reverse proxy
- `tailscale_subnet_router` - VPN routing
- `jellyfin`, `makemkv`, `media_analyzer` - Media pipeline
- `intel_gpu_passthrough`, `dual_gpu_passthrough` - GPU config
- `restic_backup` - Automated backups
- `wishlist` - Self-hosted gift registry application
- `proxmox_host_setup` - Host maintenance (repos, kernel cleanup, fstrim)
- `proxmox_container_updates` - Automated container updates
- `proxmox_host_backup` - Host config backups

### Automated Maintenance
- **Weekly**: Container updates (Sun 3AM), Host backup (Sun 2AM), FSTRIM (Sat 11PM)
- **Daily**: Restic backup to Backblaze B2 (2AM)
- **Retention**: 7 daily, 4 weekly, 6 monthly, 2 yearly

---

## Media Pipeline

```
Rip (CT302) → Remux (CT303) → Transcode (CT304) → Organize (CT303) → Serve (CT305)
```

**Directories** (`/mnt/storage/media/`):
- `staging/{1-ripped,2-remuxed,3-transcoded,4-ready}` - Pipeline stages
- `library/{movies,tv}` - Final organized media

**Scripts**: `scripts/media/production/`

---

## Quick Reference

```bash
# Container management
ssh cuiv@homelab "sudo pct list"
ssh cuiv@homelab "sudo pct enter <CTID>"

# Apply infrastructure changes
cd terraform && terraform plan && terraform apply
ansible-playbook ansible/playbooks/<service>.yml --vault-password-file .vault_pass

# Check services
ssh cuiv@homelab "sudo pct exec 304 -- vainfo"  # GPU in transcoder
ssh cuiv@homelab "sudo pct exec 302 -- ls -la /dev/sr0"  # Optical drive
```

---

**Maintenance**: Update this document when infrastructure changes occur.
