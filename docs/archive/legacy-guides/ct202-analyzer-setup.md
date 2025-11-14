# CT 202: Analyzer/Remux Container Setup

**Date**: 2025-11-10  
**Purpose**: Fast operations - analysis, remuxing, promotion, FileBot  
**Separates from**: CT 201 (transcoder) which handles heavy CPU work

## Container Specifications

- **CTID**: 202
- **Hostname**: analyzer
- **OS**: Debian 12
- **CPU**: 2 cores (cpuunits: 1024 - medium priority)
- **RAM**: 4GB
- **Disk**: 12GB
- **Type**: Privileged (for storage access simplicity)
- **Storage**: `/mnt/storage` bind mount

## Step 1: Create Container (Proxmox Host)

```bash
# On Proxmox host (root@homelab)

pct create 202 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname analyzer \
  --cores 2 \
  --memory 4096 \
  --swap 2048 \
  --rootfs local-lvm:12 \
  --net0 name=eth0,bridge=vmbr0,firewall=0,ip=dhcp \
  --unprivileged 0 \
  --features nesting=1 \
  --ostype debian \
  --tags media

# Set CPU units (medium priority)
pct set 202 --cpuunits 1024

# Add storage mount
pct set 202 -mp0 /mnt/storage,mp=/mnt/storage

# Start container
pct start 202
```

## Step 2: Configure Networking (Inside CT 202)

```bash
pct enter 202

# Setup network
ip link set eth0 up
dhclient eth0

# Make persistent
cat > /etc/network/interfaces.d/eth0 << 'EOF'
auto eth0
iface eth0 inet dhcp
EOF

# Test internet
ping -c 3 google.com

# Update system
apt update && apt upgrade -y
```

## Step 3: Create Media User

```bash
# Still in CT 202

# Create media user (UID 1000 to match host)
groupadd -g 1000 media
useradd -u 1000 -g 1000 -s /bin/bash -m media

# Verify
id media
# Should show: uid=1000(media) gid=1000(media)

# Check storage access
ls -la /mnt/storage/media/staging/
# Should be accessible
```

## Step 4: Install Required Tools

```bash
# Still in CT 202 as root

apt install -y \
  mkvtoolnix \
  mkvtoolnix-gui \
  mediainfo \
  jq \
  bc \
  rsync \
  curl \
  wget \
  nano \
  tree

# Verify installations
mkvmerge --version
mediainfo --version
jq --version
```

## Step 5: Setup Scripts Directory

```bash
# Create scripts directory for media user
mkdir -p /home/media/scripts
chown media:media /home/media/scripts

# Exit to deploy scripts from host
exit
```

## Step 6: Deploy Scripts (Proxmox Host)

```bash
# On Proxmox host

# Scripts for CT 202 (analyzer/remux operations):
# - fix-current-names.sh
# - analyze-media.sh
# - organize-and-remux-movie.sh
# - organize-and-remux-tv.sh
# - promote-to-ready.sh
# - filebot-process.sh (if FileBot installed)

# Copy from your dev machine first (or use existing /tmp/scripts/)
# Then push to container:

pct push 202 /tmp/scripts/fix-current-names.sh /home/media/scripts/fix-current-names.sh
pct push 202 /tmp/scripts/analyze-media.sh /home/media/scripts/analyze-media.sh
pct push 202 /tmp/scripts/organize-and-remux-movie.sh /home/media/scripts/organize-and-remux-movie.sh
pct push 202 /tmp/scripts/organize-and-remux-tv.sh /home/media/scripts/organize-and-remux-tv.sh
pct push 202 /tmp/scripts/promote-to-ready.sh /home/media/scripts/promote-to-ready.sh
pct push 202 /tmp/scripts/filebot-process.sh /home/media/scripts/filebot-process.sh

# Set ownership and permissions
pct exec 202 -- chown -R media:media /home/media/scripts
pct exec 202 -- chmod +x /home/media/scripts/*.sh
```

## Step 7: Test Container

```bash
pct enter 202
su - media

# Test storage access
ls -la /mnt/storage/media/staging/1-ripped/

# Test scripts
~/scripts/analyze-media.sh --help

# Test tools
mkvmerge --version
mediainfo --version
```

## Container Resource Allocation

**3-Container Setup**:

| Container | Role | Cores | CPU Units | Priority |
|-----------|------|-------|-----------|----------|
| CT 200 | Ripper | 2 | 1024 | Medium |
| **CT 202** | **Analyzer** | **2** | **1024** | **Medium** |
| CT 201 | Transcoder | 4 | 512 | Low |
| CT 101 | Jellyfin | 2 | 2048 | High |

**Total**: 10 cores allocated (6 physical available)
- Jellyfin gets priority
- Transcoder yields to everything else
- Ripper and Analyzer share medium priority

## Workflow Split

### CT 200 (Ripper)
- Rip discs → 1-ripped

### CT 202 (Analyzer) ← **NEW**
- Analyze files
- Organize and remux → 2-remuxed
- Promote → 4-ready
- FileBot → library

### CT 201 (Transcoder)
- Transcode: 2-remuxed → 3-transcoded
- (Nothing else, focus on encoding)

## Updated Workflow Commands

**Phase 1 - Rip (CT 200)**:
```bash
pct enter 200
su - media
~/scripts/rip-disc.sh show "Show Name" "S01 Disc1"
```

**Phase 2 - Analyze (CT 202)**:
```bash
pct enter 202
su - media
~/scripts/analyze-media.sh /mnt/storage/media/staging/1-ripped/movies/Movie_2024-11-10/
```

**Phase 3 - Organize/Remux (CT 202)**:
```bash
# On CT 202
~/scripts/organize-and-remux-movie.sh /mnt/storage/media/staging/1-ripped/movies/Movie_2024-11-10/
# OR for TV:
~/scripts/organize-and-remux-tv.sh "Show Name" 01
```

**Phase 4 - Transcode (CT 201)**:
```bash
pct enter 201
su - media
~/scripts/transcode-queue.sh /mnt/storage/media/staging/2-remuxed/movies/Movie_2024-11-10/ 20 software --auto
```

**Phase 5 - Promote (CT 202)**:
```bash
# On CT 202
~/scripts/promote-to-ready.sh /mnt/storage/media/staging/3-transcoded/movies/Movie_2024-11-10/
```

**Phase 6 - FileBot (CT 202)**:
```bash
# On CT 202
~/scripts/filebot-process.sh /mnt/storage/media/staging/4-ready/movies/Movie_Name/
```

## Benefits of This Split

✅ **Ripper can run while transcoding** - no interference  
✅ **Can remux/analyze while transcoding** - transcoder has low priority  
✅ **FileBot operations don't compete with transcode** - on separate container  
✅ **Transcoder focuses purely on encoding** - maximum efficiency  
✅ **Fast operations stay fast** - not waiting for transcoder CPU  

## FileBot Installation (Optional)

If you want FileBot on CT 202:

```bash
pct enter 202

# Install dependencies
apt install -y openjdk-17-jre-headless

# Download FileBot (check latest version)
wget https://get.filebot.net/filebot/FileBot_5.1.3/FileBot_5.1.3_amd64.deb
dpkg -i FileBot_5.1.3_amd64.deb

# Or use snap
apt install snapd
snap install filebot

# Verify
filebot --version
```

## Verification Checklist

- [ ] Container created (CTID 202)
- [ ] Network configured and working
- [ ] Media user created (UID 1000)
- [ ] Storage accessible (/mnt/storage)
- [ ] Tools installed (mkvtoolnix, mediainfo, jq, bc)
- [ ] Scripts deployed and executable
- [ ] Can access 1-ripped files
- [ ] Can write to 2-remuxed

## Next Steps

1. Run `fix-current-names.sh` to fix existing Avatar/Cosmos files
2. Test analyze on one movie
3. Test organize-and-remux on one movie
4. Verify files land in 2-remuxed correctly
5. Let CT 201 continue transcoding independently

---

**Status**: Ready to deploy  
**Time to setup**: 15-20 minutes  
**Impact**: None on existing containers
