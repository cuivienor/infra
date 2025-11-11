# Quick Reference Card

One-page reference for the most commonly needed information.

---

## SSH Access

```bash
ssh homelab        # Main Proxmox host (192.168.1.56)
```

## Container Access

| CTID | Name | IP | Purpose | Access |
|------|------|-----|---------|--------|
| 101 | jellyfin | 192.168.1.128 | Media server | `ssh root@192.168.1.128` |
| 200 | ripper-new | 192.168.1.75 | Blu-ray ripping | `pct enter 200` |
| 201 | transcoder-new | 192.168.1.77 | Video transcoding | `pct enter 201` |
| 202 | analyzer | 192.168.1.72 | Media analysis | `pct enter 202` |

## Common Commands

### Proxmox Host
```bash
# List all containers
pct list

# Enter container
pct enter <CTID>

# Start/stop container
pct start <CTID>
pct stop <CTID>

# View container config
cat /etc/pve/lxc/<CTID>.conf

# Check storage
df -h /mnt/storage
```

### Container Management
```bash
# Check GPU in transcoder
pct exec 201 -- vainfo --display drm --device /dev/dri/renderD128

# Check optical drive in ripper
pct exec 200 -- ls -la /dev/sr0 /dev/sg4

# Get container IP
pct exec <CTID> -- hostname -I

# Run command as media user
pct exec <CTID> -- su - media -c 'command here'
```

### Media Scripts
```bash
# All scripts in: scripts/media/

# Rip disc
sudo -u media scripts/media/rip-disc.sh

# Transcode media
sudo -u media scripts/media/transcode-media.sh

# Organize media
sudo -u media scripts/media/organize-media.sh
```

## Key Paths

### On Host
- **LXC Configs**: `/etc/pve/lxc/<CTID>.conf`
- **Storage Mount**: `/mnt/storage`
- **fstab**: `/etc/fstab`

### In Containers
- **Storage**: `/mnt/storage`
- **Media Staging**: `/mnt/storage/media/staging/`
- **Media Library**: `/mnt/storage/media/{movies,tv}/`

### In Repository
- **Terraform**: `terraform/`
- **Ansible**: `ansible/`
- **Scripts**: `scripts/media/`
- **Docs**: `docs/{guides,reference,plans}/`

## Hardware Devices

### Intel Arc A380 (Transcoding GPU)
- **Container**: CT201 (transcoder-new)
- **Devices**: `/dev/dri/card1`, `/dev/dri/renderD128`
- **Test**: `vainfo --display drm --device /dev/dri/renderD128`

### Optical Drive (Blu-ray)
- **Container**: CT200 (ripper-new)
- **Devices**: `/dev/sr0`, `/dev/sg4`
- **Test**: `makemkvcon info disc:0`

## Media User

- **Username**: `media`
- **UID/GID**: `1000:1000`
- **Exists on**: Host + all containers
- **Groups**: 
  - Host: `media`, `cdrom`, `video`, `render`
  - CT200: `media`, `cdrom`
  - CT201: `media`, `video`, `render`

## Storage

### MergerFS Pool
- **Mount**: `/mnt/storage`
- **Total**: 35TB
- **Used**: 4.1TB (13%)
- **Disks**: 
  - disk1: 9.1TB (48% used)
  - disk2: 9.1TB (1% used)
  - disk3: 17TB (1% used)
  - parity: 17TB (20% used)

### Media Directories
```
/mnt/storage/media/
├── staging/
│   ├── 0-raw/      # Raw MakeMKV output
│   ├── 1-ripped/   # Transcoded files
│   └── 2-ready/    # Organized, ready to move
├── movies/         # Movie library
└── tv/            # TV show library
```

## Documentation

### Essential Reads
1. **`AGENTS.md`** - AI context and conventions
2. **`docs/reference/current-state.md`** - Complete system details
3. **`docs/reference/homelab-iac-strategy.md`** - IaC plan
4. **`notes/wip/SYSTEM-SNAPSHOT.md`** - Current status

### When Starting Work
```bash
# 1. Check current status
cat notes/wip/SYSTEM-SNAPSHOT.md

# 2. Review system state
cat docs/reference/current-state.md

# 3. Check IaC strategy
cat docs/reference/homelab-iac-strategy.md
```

## System Specs

| Component | Details |
|-----------|---------|
| **Host** | homelab (192.168.1.56) |
| **OS** | Proxmox VE 8.4.14 |
| **CPU** | Intel i5-9600K (6 cores) |
| **RAM** | 32GB |
| **Storage** | 35TB MergerFS |
| **GPU1** | Intel Arc A380 (transcoding) |
| **GPU2** | NVIDIA GTX 1080 (display) |

## Git Workflow

```bash
# Check status
git status

# Add files
git add <file>

# Commit with good message
git commit -m "type: description"

# Push to remote
git push
```

### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactoring
- `chore`: Maintenance
- `test`: Testing

## Troubleshooting

### Container won't start
```bash
# Check config
cat /etc/pve/lxc/<CTID>.conf

# Check logs
journalctl -u pve-container@<CTID> -n 50

# Try manual start
pct start <CTID>
```

### GPU not working
```bash
# Check devices exist in container
pct exec 201 -- ls -la /dev/dri/

# Check groups
pct exec 201 -- id media

# Verify VA-API
pct exec 201 -- vainfo --display drm --device /dev/dri/renderD128
```

### Storage issues
```bash
# Check mount
df -h /mnt/storage

# Check ownership
ls -ld /mnt/storage/media

# Remount if needed
mount -a
```

---

**Quick Start**: `ssh homelab` → `pct list` → `pct enter <CTID>`  
**Full Docs**: See `docs/reference/current-state.md`  
**Help**: Check `AGENTS.md` for AI assistance guidelines
