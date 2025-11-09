# Transcoding LXC Container Setup Guide

## Overview

This guide documents the setup of a Debian 12 LXC container on Proxmox for transcoding Blu-ray rips using ffmpeg with Intel Arc GPU support.

## Requirements

- Proxmox host with Intel Arc GPU (identified as `/dev/dri/card0` and `/dev/dri/renderD128`)
- MergerFS storage at `/mnt/storage/media/` on host
- Media files stored in `/mnt/storage/media/staging/`

## Container Specifications

- **Base**: Debian 12 (bookworm)
- **Disk**: 20GB
- **CPU**: 4-8 cores
- **Memory**: 8GB
- **Hostname**: transcoder (or your choice)

## Step 1: Identify Intel GPU on Proxmox Host

```bash
# List GPU devices
ls -l /dev/dri/

# Identify which card is Intel Arc
for card in /sys/class/drm/card*; do
  if [ -e "$card/device/vendor" ]; then
    vendor=$(cat "$card/device/vendor")
    device=$(cat "$card/device/device")
    echo "$(basename $card): Vendor=$vendor Device=$device"
    lspci -nn -d ${vendor#0x}:${device#0x}
    echo
  fi
done

# Intel vendor ID: 0x8086
# NVIDIA vendor ID: 0x10de
```

In our case: Intel Arc is `/dev/dri/card0` and `/dev/dri/renderD128`

## Step 2: Get Required GID/UID Information

```bash
# On Proxmox host, identify groups needed for GPU access
getent group render | cut -d: -f3  # Returns: 104
getent group video | cut -d: -f3   # Returns: 44

# Check media storage ownership
ls -ld /mnt/storage/media/staging/ # Returns: user 1005, group 1005
```

## Step 3: Configure Proxmox for Container Mapping

```bash
# On Proxmox host, grant permissions for GID/UID mapping
echo "root:44:1" >> /etc/subgid    # video group
echo "root:104:1" >> /etc/subgid   # render group
echo "root:1005:1" >> /etc/subuid  # media user
echo "root:1005:1" >> /etc/subgid  # media group
```

## Step 4: Create Container

Create the container through Proxmox UI with specifications above, then **stop it before first start**.

## Step 5: Configure Container

Edit `/etc/pve/lxc/<CTID>.conf` on Proxmox host:

```bash
nano /etc/pve/lxc/<CTID>.conf
```

Add these lines:

```conf
# Intel Arc GPU passthrough
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri/card0 dev/dri/card0 none bind,optional,create=file
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file

# MergerFS media storage
mp0: /mnt/storage/media,mp=/mnt/media

# UID/GID mappings for GPU access and media storage
lxc.idmap: u 0 100000 1005
lxc.idmap: u 1005 1005 1
lxc.idmap: u 1006 101006 64530
lxc.idmap: g 0 100000 44
lxc.idmap: g 44 44 1
lxc.idmap: g 45 100045 59
lxc.idmap: g 104 104 1
lxc.idmap: g 105 100105 860
lxc.idmap: g 1005 1005 1
lxc.idmap: g 1006 101006 64530

# Features and firewall
features: nesting=1
firewall: 0
```

**Important Notes:**
- `firewall: 0` is required for network connectivity
- The idmap lines create non-overlapping ranges to map host GIDs (44, 104, 1005) into the container
- Adjust GID/UID numbers if your host uses different values

## Step 6: Start Container and Fix Networking

```bash
# On Proxmox host
pct start <CTID>
pct enter <CTID>
```

### Fix Network Interface (Common Issue)

If network is down after first boot:

```bash
# Inside container - bring up interface
ip link set eth0 up
dhclient eth0

# Make permanent - edit /etc/network/interfaces
nano /etc/network/interfaces
```

Add:
```
auto eth0
iface eth0 inet dhcp
```

Reboot container to verify networking persists.

## Step 7: Install Software Inside Container

```bash
# Update package list
apt update

# Enable non-free repos for Intel drivers
echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list.d/non-free.list
apt update

# Install Intel media drivers and tools
apt install -y intel-media-va-driver vainfo ffmpeg mediainfo mkvtoolnix

# Create groups and add root to them
groupadd -g 44 video
groupadd -g 104 render
groupadd -g 1005 media

usermod -a -G video,render,media root
```

## Step 8: Verify GPU Access

**IMPORTANT**: After adding root to groups, you must get a fresh login shell:

```bash
# Exit container
exit

# Re-enter with proper login shell to pick up group memberships
pct enter <CTID> -- su - root

# Verify groups
groups
# Should show: root video render media

id
# Should show: uid=0(root) gid=0(root) groups=0(root),44(video),104(render),1005(media)

# Test GPU access
vainfo --display drm --device /dev/dri/renderD128

# Verify ffmpeg sees QSV
ffmpeg -hwaccels
# Should list: qsv

# List QSV encoders
ffmpeg -encoders | grep qsv
# Should show hevc_qsv and h264_qsv among others
```

## Step 9: Fix Storage Permissions

**On Proxmox host**, make storage group-writable:

```bash
# Make mergerfs storage group-writable
chmod -R g+w /mnt/storage/
```

Verify permissions changed:
```bash
ls -ld /mnt/storage/media/staging/
# Should show: drwxrwxr-x (note the 'w' in group permissions)
```

## Transcoding Command

Generic command for Blu-ray transcoding with English/Bulgarian tracks:

```bash
ffmpeg -i INPUT.mkv \
  -map 0:v:0 \
  -map 0:a:m:language:eng \
  -map 0:a:m:language:bul? \
  -map 0:s:m:language:eng? \
  -map 0:s:m:language:bul? \
  -c:v libx265 \
  -preset slow \
  -crf 18 \
  -c:a copy \
  -c:s copy \
  OUTPUT.mkv
```

**Parameters Explained:**
- `-map 0:v:0` - First video stream
- `-map 0:a:m:language:eng` - ALL English audio tracks
- `-map 0:a:m:language:bul?` - Bulgarian audio if present (? = optional)
- `-map 0:s:m:language:eng?` - English subtitles if present
- `-map 0:s:m:language:bul?` - Bulgarian subtitles if present
- `-c:v libx265` - Encode video to x265/HEVC
- `-preset slow` - Better compression, slower encoding
- `-crf 18` - High quality (18-22 typical for Blu-ray, lower = better quality)
- `-c:a copy` - Keep original audio format (DTS, TrueHD, etc.)
- `-c:s copy` - Keep original subtitle format

**Example Usage:**

```bash
# Navigate to staging directory
cd /mnt/media/staging

# Transcode a file
ffmpeg -i "Movie.Title.2024.mkv" \
  -map 0:v:0 \
  -map 0:a:m:language:eng \
  -map 0:a:m:language:bul? \
  -map 0:s:m:language:eng? \
  -map 0:s:m:language:bul? \
  -c:v libx265 \
  -preset slow \
  -crf 18 \
  -c:a copy \
  -c:s copy \
  "/mnt/media/movies/Movie.Title.2024.mkv"
```

## Known Issues

### Write Permissions to /mnt/media

**Status**: Unresolved at time of writing

Even with correct group memberships and permissions, writing to `/mnt/media/staging/` may fail with "Permission denied".

**What we've verified:**
- ✅ Host permissions are correct (`rwxrwxr-x`)
- ✅ Container sees correct ownership (user/group 1005)
- ✅ Root is member of media group (1005)
- ✅ Group membership active in shell session
- ❌ Still cannot write

**Potential causes to investigate:**
1. MergerFS mount options may need `allow_other` or `default_permissions`
2. Container mp0 mount may need explicit `ro=0` flag
3. SELinux/AppArmor restrictions (unlikely on standard Debian)

**Workaround**: Output to a different location or run ffmpeg as user 1005

## Troubleshooting

### Container Won't Start After Config Changes

Check logs:
```bash
# On Proxmox host
pct start <CTID>
journalctl -xe
```

Common issues:
- Overlapping idmap ranges (check for conflicts in ranges)
- Missing entries in `/etc/subuid` or `/etc/subgid`
- Invalid device node numbers in cgroup2 allow rules

### GPU Not Accessible

```bash
# Verify devices exist
ls -l /dev/dri/

# Check ownership/permissions
stat /dev/dri/renderD128

# Verify group membership with fresh login
exit
pct enter <CTID> -- su - root
groups
```

### Network Issues

```bash
# Check interface status
ip addr show

# Bring up interface
ip link set eth0 up
dhclient eth0

# Verify routing
ip route show
ping 8.8.8.8
```

## Future Automation Ideas

Once manual transcoding is working:
1. Script to batch process all files in staging
2. Automatic language track detection and selection
3. Quality presets for different content types (4K, 1080p, SD extras)
4. Integration with file monitoring (inotify) for automatic processing
5. Notification system when transcoding completes

## Reference

Based on guide: https://forum.jellyfin.org/t-from-disc-to-drive-a-beginner-s-guide-to-preparing-your-media-for-jellyfin

Key decisions:
- **Software encoding** (libx265) chosen over hardware (QSV) for best quality/compression
- **CRF 18** balances quality and file size for Blu-ray sources
- **Audio passthrough** preserves high-quality formats (DTS-HD, TrueHD) for AVR playback
