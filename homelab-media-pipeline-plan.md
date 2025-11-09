# Homelab Media Pipeline Reconstruction Plan

**Date**: 2025-01-09
**Status**: Ready to Execute

## Executive Summary

This plan rebuilds your Proxmox container infrastructure for Blu-ray ripping and transcoding with:
- **Hybrid security model**: Privileged containers (ripper + transcoder) for simplicity
- **Unified media user**: UID/GID 1000 across all containers and host
- **Simplified permissions**: No complex idmap configuration needed
- **Community script patterns**: Following proven homelab practices from https://community-scripts.github.io/ProxmoxVE/scripts

## Background & Decisions Made

### Research Findings

1. **Community Scripts Analysis**:
   - Tdarr, Jellyfin, Plex all default to unprivileged with GPU support
   - GPU passthrough works in unprivileged BUT requires complex idmap
   - Optical drive passthrough is problematic in unprivileged (privileged recommended)
   - All scripts use dynamic group membership (video/render) for GPU access
   - No scripts handle storage mounts (manual Proxmox configuration)
   - Standard pattern: Install app, configure hardware, leave storage to admin

2. **Privileged vs Unprivileged Trade-offs**:
   - **Unprivileged**: Better security, complex idmap, optical drive issues
   - **Privileged**: Simpler setup, hardware "just works", lower isolation security
   - **For homelab**: Privileged is pragmatic choice when network-isolated

3. **UID/GID Standards**:
   - Industry standard: Single "media" user with consistent UID across containers
   - Most common: UID/GID 1000 (first user on Linux systems)
   - Alternative: 1005 (your current setup) - but 1000 is cleaner
   - LinuxServer.io convention: PUID/PGID environment variables

### Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Container security | **Hybrid: Both privileged** | Optical drive needs privileged; transcoder simplified with privileged |
| Media user UID/GID | **1000** | Industry standard, clean start, most compatible |
| Existing transcoder | **Recreate as privileged** | Fixes permission issues, removes idmap complexity |
| Storage approach | **Unified media user ownership** | All services as same user, no permission conflicts |
| Automation | **Custom scripts + generic docs** | Educational value, based on community patterns |

## Phase 1: Host-Level Setup

### 1.1 Create Unified Media User on Proxmox Host

```bash
# Create media user with UID/GID 1000
useradd -u 1000 -g 1000 -s /bin/bash -m media

# Add to hardware access groups
usermod -a -G video,render,cdrom media

# Verify groups
id media
# Should show: uid=1000(media) gid=1000(media) groups=1000(media),44(video),104(render),24(cdrom)

# Set storage ownership
chown -R media:media /mnt/storage

# Ensure group-writable
chmod -R g+w /mnt/storage

# Verify permissions
ls -ld /mnt/storage/media/staging/
# Should show: drwxrwxr-x ... media media
```

**Why**:
- UID 1000 is the standard first user on Linux
- Same UID in host and containers means files owned by "media" everywhere
- Group memberships (video/render/cdrom) grant hardware access
- Group-writable allows automation and manual edits

### 1.2 Verify MergerFS Mount Options

```bash
# Check current mount
mount | grep mergerfs

# Should include 'allow_other' option
# Example: /mnt/disk* on /mnt/storage type fuse.mergerfs (rw,allow_other,use_ino)
```

If `allow_other` is missing, edit `/etc/fstab`:
```
/mnt/disk* /mnt/storage fuse.mergerfs defaults,allow_other,use_ino,cache.files=off,category.create=mfs 0 0
```

Then remount:
```bash
umount /mnt/storage
mount /mnt/storage
```

**Why**: `allow_other` allows containers to access the mergerfs mount.

## Phase 2: Destroy and Recreate Transcoding Container

### 2.1 Backup Current Configuration

```bash
# Backup LXC config
cp /etc/pve/lxc/<CURRENT_CTID>.conf ~/transcoder-old-config-$(date +%Y%m%d).backup

# Document current CTID
echo "Old transcoder CT ID: <CURRENT_CTID>" > ~/container-migration-notes.txt
```

### 2.2 Destroy Current Container

```bash
# Stop container
pct stop <CURRENT_CTID>

# Destroy (removes all data)
pct destroy <CURRENT_CTID>
```

### 2.3 Create New Privileged Transcoding Container

**Via Proxmox Web UI**:
1. Click "Create CT"
2. General:
   - CT ID: Choose new ID (e.g., 201)
   - Hostname: `transcoder`
   - **Unprivileged container**: UNCHECK (make it privileged)
   - Password: Set root password
3. Template:
   - Storage: local
   - Template: debian-12-standard_12.7-1_amd64.tar.zst
4. Disks:
   - Disk size: 20 GB
5. CPU:
   - Cores: 8
6. Memory:
   - Memory: 8192 MB
   - Swap: 2048 MB
7. Network:
   - Bridge: vmbr0
   - DHCP or static IP
8. DNS: Use host settings
9. Confirm

**DO NOT START YET**

### 2.4 Configure Container LXC Config

```bash
# Edit config
nano /etc/pve/lxc/<NEW_CTID>.conf
```

Add these lines:

```conf
# Intel Arc GPU passthrough (privileged - simple)
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir

# MergerFS storage mount (full access)
mp0: /mnt/storage,mp=/mnt/storage

# Features
features: nesting=1

# Disable firewall (fix networking issues)
firewall: 0
```

**What this does**:
- `lxc.cgroup2.devices.allow`: Grants access to GPU device nodes (226:0 = card0, 226:128 = renderD128)
- `lxc.mount.entry`: Bind-mounts entire /dev/dri directory into container
- `mp0`: Mounts host /mnt/storage to container /mnt/storage
- `nesting=1`: Allows running containers inside (useful for Docker if needed)
- `firewall: 0`: Disables Proxmox firewall (networking issue workaround)

**Note**: NO idmap configuration needed! Privileged containers see host UIDs directly.

### 2.5 Start Container and Fix Networking

```bash
# Start container
pct start <NEW_CTID>

# Enter container
pct enter <NEW_CTID>

# Check network interface
ip addr show
# If eth0 is down, bring it up:
ip link set eth0 up
dhclient eth0

# Make network permanent
nano /etc/network/interfaces
```

Add:
```
auto eth0
iface eth0 inet dhcp
```

Exit and restart to verify:
```bash
exit
pct reboot <NEW_CTID>
pct enter <NEW_CTID>
ping -c 3 8.8.8.8
```

## Phase 3: Install Transcoding Software (Inside Container)

### 3.1 Create Media User

```bash
# Inside container
useradd -u 1000 -g 1000 -s /bin/bash -m media

# Add to GPU groups
groupadd -g 44 video      # May already exist
groupadd -g 104 render    # May already exist
usermod -a -G video,render media

# Verify
id media
# Should show: uid=1000(media) gid=1000(media) groups=1000(media),44(video),104(render)
```

### 3.2 Install Intel GPU Drivers

```bash
# Update package list
apt update

# Enable non-free repos
echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list.d/non-free.list
apt update

# Install Intel GPU drivers and tools
apt install -y \
  intel-media-va-driver \
  va-driver-all \
  vainfo \
  intel-gpu-tools \
  mesa-va-drivers \
  mesa-vdpau-drivers
```

### 3.3 Install Transcoding Tools

```bash
# Install ffmpeg and HandBrake
apt install -y \
  ffmpeg \
  handbrake-cli \
  mediainfo \
  mkvtoolnix

# Optional: Install Tdarr (for automation later)
# Follow community script pattern from proxmox-scripts/install/tdarr-install.sh
```

### 3.4 Fix GPU Permissions (Privileged Container)

```bash
# Set permissions on GPU devices (privileged containers need this)
chgrp video /dev/dri
chmod 755 /dev/dri
chmod 660 /dev/dri/*
```

### 3.5 Verify GPU Access

**Must use fresh login to pick up group memberships:**

```bash
# Exit container
exit

# Re-enter as root but force new login shell
pct enter <NEW_CTID> -- su - root

# Switch to media user
su - media

# Test GPU access
vainfo --display drm --device /dev/dri/renderD128

# Should show: Intel Arc GPU with supported profiles

# Check ffmpeg
ffmpeg -hwaccels
# Should list: qsv

ffmpeg -encoders | grep qsv
# Should show: hevc_qsv, h264_qsv, etc.
```

### 3.6 Test Storage Write Permissions

```bash
# As media user
touch /mnt/storage/staging/test-write.txt
ls -l /mnt/storage/staging/test-write.txt
# Should show: media media

# Clean up
rm /mnt/storage/staging/test-write.txt
```

**If this fails**:
- Check host ownership: `ls -ld /mnt/storage/staging/` (on host)
- Should be media:media with group write (rwxrwxr-x)
- Fix on host: `chown -R media:media /mnt/storage && chmod -R g+w /mnt/storage`

## Phase 4: Transcoding Command & Testing

### 4.1 Generic Transcoding Command

```bash
# As media user in container
cd /mnt/storage/staging

# Generic command for Blu-ray transcoding
ffmpeg -i "INPUT.mkv" \
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
  "/mnt/storage/media/movies/OUTPUT.mkv"
```

**Parameters**:
- `-map 0:v:0`: First video stream
- `-map 0:a:m:language:eng`: ALL English audio tracks
- `-map 0:a:m:language:bul?`: Bulgarian audio if exists (? = optional)
- `-map 0:s:m:language:eng?`: English subtitles if exist
- `-map 0:s:m:language:bul?`: Bulgarian subtitles if exist
- `-c:v libx265`: Encode to x265/HEVC (software encoding for best quality)
- `-preset slow`: Better compression, slower encode
- `-crf 18`: High quality (18-22 for Blu-ray, lower = better)
- `-c:a copy`: Keep original audio formats (DTS, TrueHD, etc.)
- `-c:s copy`: Keep original subtitle formats

### 4.2 Test Transcoding

```bash
# Pick a sample file
ls /mnt/storage/staging/

# Analyze tracks
mediainfo "/mnt/storage/staging/YOUR_SAMPLE.mkv"

# Test transcode (use small segment first)
ffmpeg -i "/mnt/storage/staging/YOUR_SAMPLE.mkv" \
  -t 60 \
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
  "/mnt/storage/staging/test-output.mkv"

# Check output
ls -lh /mnt/storage/staging/test-output.mkv
mediainfo /mnt/storage/staging/test-output.mkv
```

**Monitoring**:
```bash
# In another terminal, monitor GPU usage
watch -n 1 intel_gpu_top

# Or CPU usage (software encoding)
htop
```

## Phase 5: MakeMKV Ripper Container

### 5.1 Create Ripper Container

**Via Proxmox Web UI**:
1. Create CT (similar to transcoder)
   - CT ID: Choose ID (e.g., 202)
   - Hostname: `ripper`
   - **Privileged** (uncheck unprivileged)
   - Debian 12 template
   - 4 CPU cores, 4GB RAM, 20GB disk

**DO NOT START YET**

### 5.2 Configure Ripper LXC Config

```bash
nano /etc/pve/lxc/<RIPPER_CTID>.conf
```

Add:

```conf
# Optical drive passthrough (privileged only)
lxc.cgroup2.devices.allow: c 11:0 rwm       # /dev/sr0 (optical drive)
lxc.cgroup2.devices.allow: c 21:* rwm       # SCSI generic devices
lxc.mount.entry: /dev/sr0 dev/sr0 none bind,optional,create=file
lxc.mount.entry: /dev/sg0 dev/sg0 none bind,optional,create=file
lxc.mount.entry: /dev/sg1 dev/sg1 none bind,optional,create=file

# MergerFS storage (read-write to staging)
mp0: /mnt/storage,mp=/mnt/storage

# Features
features: nesting=1
firewall: 0
```

**Device explanation**:
- `/dev/sr0`: Optical drive block device
- `/dev/sg0`, `/dev/sg1`: SCSI generic interface (needed for full MakeMKV functionality)
- May need to adjust sg* numbers based on your hardware

### 5.3 Start and Configure Ripper

```bash
pct start <RIPPER_CTID>
pct enter <RIPPER_CTID>

# Fix networking if needed (same as transcoder)
ip link set eth0 up
dhclient eth0
nano /etc/network/interfaces  # Add auto eth0 / iface eth0 inet dhcp

# Create media user
useradd -u 1000 -g 1000 -s /bin/bash -m media

# Add to cdrom group
groupadd -g 24 cdrom  # May already exist
usermod -a -G cdrom media

# Verify
id media
```

### 5.4 Install MakeMKV

```bash
# Add MakeMKV repository
echo "deb http://www.makemkv.com/forum/debian/ bookworm main" > /etc/apt/sources.list.d/makemkv.list

# Add GPG key (check makemkv.com forum for current key)
wget -qO- http://www.makemkv.com/forum/repo.pubkey | apt-key add -

# Update and install
apt update
apt install -y makemkv-bin makemkv-oss

# Or manual install from https://www.makemkv.com/download/
```

**Alternative (manual build)**:
```bash
# Dependencies
apt install -y build-essential pkg-config libc6-dev libssl-dev libexpat1-dev libavcodec-dev libgl1-mesa-dev qtbase5-dev zlib1g-dev

# Download and build (check makemkv.com for latest version)
cd /tmp
wget https://www.makemkv.com/download/makemkv-bin-VERSION.tar.gz
wget https://www.makemkv.com/download/makemkv-oss-VERSION.tar.gz

# Build oss
tar xvzf makemkv-oss-VERSION.tar.gz
cd makemkv-oss-VERSION
./configure
make
make install

# Install bin
cd ..
tar xvzf makemkv-bin-VERSION.tar.gz
cd makemkv-bin-VERSION
make
make install
```

### 5.5 Configure MakeMKV

```bash
# Run as media user
su - media

# Create config directory
mkdir -p ~/.MakeMKV

# Set default output directory
cat > ~/.MakeMKV/settings.conf << EOF
app_DefaultOutputFileName="{t}"
app_DefaultSelectionString="+sel:all,+sel:subtitle,-sel:subtitle=forced"
app_DestinationDir="/mnt/storage/media/staging"
EOF

# Test drive access
makemkvcon info disc:0
```

### 5.6 Test Ripping

```bash
# As media user
# Insert disc

# Get disc info
makemkvcon info disc:0

# Rip to staging
makemkvcon mkv disc:0 all /mnt/storage/media/staging/

# Check output
ls -lh /mnt/storage/media/staging/
# Files should be owned by media:media
```

## Phase 6: Documentation & Scripts

### 6.1 Create Installation Scripts

**File: `transcoder-install.sh`**
```bash
#!/usr/bin/env bash
# Transcoder Container Setup Script
# Based on community-scripts.github.io patterns
# For Debian 12 LXC container

set -e

echo "=== Transcoder Container Installation ==="

# Create media user
echo "Creating media user (UID 1000)..."
useradd -u 1000 -g 1000 -s /bin/bash -m media || true

# Create groups if they don't exist
groupadd -g 44 video || true
groupadd -g 104 render || true

# Add media to groups
usermod -a -G video,render media

# Update packages
echo "Updating packages..."
apt update

# Enable non-free repos
echo "Enabling non-free repositories..."
echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list.d/non-free.list
apt update

# Install GPU drivers
echo "Installing Intel GPU drivers..."
apt install -y \
  intel-media-va-driver \
  va-driver-all \
  vainfo \
  intel-gpu-tools \
  mesa-va-drivers \
  mesa-vdpau-drivers

# Install transcoding tools
echo "Installing ffmpeg and HandBrake..."
apt install -y \
  ffmpeg \
  handbrake-cli \
  mediainfo \
  mkvtoolnix

# Fix GPU permissions (privileged container)
echo "Setting GPU permissions..."
chgrp video /dev/dri
chmod 755 /dev/dri
chmod 660 /dev/dri/* 2>/dev/null || true

# Cleanup
echo "Cleaning up..."
apt autoremove -y
apt autoclean

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Exit and re-enter container: exit && pct enter <CTID> -- su - root"
echo "2. Switch to media user: su - media"
echo "3. Test GPU: vainfo --display drm --device /dev/dri/renderD128"
echo "4. Test ffmpeg: ffmpeg -hwaccels"
echo ""
```

**File: `makemkv-install.sh`**
```bash
#!/usr/bin/env bash
# MakeMKV Ripper Container Setup Script
# For Debian 12 LXC container with optical drive

set -e

echo "=== MakeMKV Ripper Container Installation ==="

# Create media user
echo "Creating media user (UID 1000)..."
useradd -u 1000 -g 1000 -s /bin/bash -m media || true

# Create cdrom group
groupadd -g 24 cdrom || true

# Add media to cdrom group
usermod -a -G cdrom media

# Update packages
echo "Updating packages..."
apt update

# Install dependencies
echo "Installing dependencies..."
apt install -y \
  build-essential \
  pkg-config \
  libc6-dev \
  libssl-dev \
  libexpat1-dev \
  libavcodec-dev \
  libgl1-mesa-dev \
  qtbase5-dev \
  zlib1g-dev \
  wget

# Note: Manual MakeMKV installation required
# Download from https://www.makemkv.com/download/
echo ""
echo "=== Manual MakeMKV Installation Required ==="
echo ""
echo "1. Download latest makemkv-oss and makemkv-bin from:"
echo "   https://www.makemkv.com/download/"
echo ""
echo "2. Build makemkv-oss:"
echo "   tar xvzf makemkv-oss-*.tar.gz"
echo "   cd makemkv-oss-*"
echo "   ./configure && make && make install"
echo ""
echo "3. Install makemkv-bin:"
echo "   tar xvzf makemkv-bin-*.tar.gz"
echo "   cd makemkv-bin-*"
echo "   make && make install"
echo ""
echo "4. Test: makemkvcon info disc:0"
echo ""
```

### 6.2 Update Documentation

Create comprehensive docs (see next section for file contents).

## Phase 7: Generic Container Setup Pattern

### Pattern for Any Media Container

**Host Setup (once)**:
```bash
# 1. Create media user on host
useradd -u 1000 -g 1000 media
usermod -a -G video,render,cdrom media

# 2. Set storage ownership
chown -R media:media /mnt/storage
chmod -R g+w /mnt/storage
```

**Container Config (per container)**:
```conf
# /etc/pve/lxc/<CTID>.conf

# For GPU access
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir

# For optical drive
lxc.cgroup2.devices.allow: c 11:0 rwm
lxc.cgroup2.devices.allow: c 21:* rwm
lxc.mount.entry: /dev/sr0 dev/sr0 none bind,optional,create=file

# For storage
mp0: /mnt/storage,mp=/mnt/storage

# Standard features
features: nesting=1
firewall: 0
```

**Inside Container (every container)**:
```bash
# 1. Create media user with same UID
useradd -u 1000 -g 1000 -m media

# 2. Add to hardware groups
groupadd -g 44 video || true
groupadd -g 104 render || true
groupadd -g 24 cdrom || true
usermod -a -G video,render,cdrom media

# 3. Install application
apt install -y <your-app>

# 4. Configure app to run as media user
# (via systemd User=media or su - media -c "command")
```

**Key Principle**: Same UID everywhere = files owned by "media" everywhere

## Troubleshooting Guide

### Issue: Network not working after container start

**Symptoms**: `apt update` fails, can't ping internet

**Solution**:
```bash
# Inside container
ip link set eth0 up
dhclient eth0

# Make permanent
echo "auto eth0" >> /etc/network/interfaces
echo "iface eth0 inet dhcp" >> /etc/network/interfaces
```

### Issue: GPU not accessible

**Symptoms**: `vainfo` fails, `/dev/dri/` empty or wrong permissions

**Check**:
```bash
# Inside container
ls -l /dev/dri/
# Should show renderD128 and card0

# Check groups
groups
# Should include video, render

# If groups missing, add and re-login
usermod -a -G video,render $(whoami)
exit
# Re-enter container with fresh login
```

**Fix permissions (privileged)**:
```bash
chgrp video /dev/dri
chmod 755 /dev/dri
chmod 660 /dev/dri/*
```

### Issue: Can't write to /mnt/storage

**Symptoms**: `touch /mnt/storage/test.txt` fails with permission denied

**Check ownership**:
```bash
# On host
ls -ld /mnt/storage/media/staging/
# Should be: drwxrwxr-x media media

# Inside container
id
# Should show UID 1000 (media)

ls -ld /mnt/storage/media/staging/
# Should also show media media (same UID)
```

**Fix on host**:
```bash
chown -R media:media /mnt/storage
chmod -R g+w /mnt/storage
```

### Issue: Optical drive not found

**Symptoms**: `/dev/sr0` missing in container

**Check on host**:
```bash
ls -l /dev/sr0
# Should exist on host

# Check if disc inserted
# Check dmesg for drive detection
```

**Fix container config**:
```bash
nano /etc/pve/lxc/<CTID>.conf

# Ensure these lines present:
lxc.cgroup2.devices.allow: c 11:0 rwm
lxc.mount.entry: /dev/sr0 dev/sr0 none bind,optional,create=file

# Restart container
pct stop <CTID>
pct start <CTID>
```

## Summary & Next Steps

### What You'll Have

1. **Transcoder Container**: Privileged Debian 12 with ffmpeg, HandBrake, Intel Arc GPU support
2. **Ripper Container**: Privileged Debian 12 with MakeMKV, optical drive access
3. **Unified Permissions**: Media user (UID 1000) across host and all containers
4. **Working Workflows**:
   - Rip Blu-ray → /mnt/storage/staging/
   - Transcode → /mnt/storage/movies/
   - All files owned by media:media
5. **Documentation**: Complete setup instructions and troubleshooting guide

### Execution Checklist

- [ ] Phase 1: Create media user on Proxmox host
- [ ] Phase 1: Verify mergerfs mount has `allow_other`
- [ ] Phase 2: Backup old transcoder config
- [ ] Phase 2: Destroy old transcoder container
- [ ] Phase 2: Create new privileged transcoder container
- [ ] Phase 2: Configure transcoder LXC config
- [ ] Phase 2: Start transcoder and fix networking
- [ ] Phase 3: Install transcoding software
- [ ] Phase 3: Create media user in container
- [ ] Phase 3: Verify GPU access
- [ ] Phase 3: Test write permissions
- [ ] Phase 4: Test transcoding command
- [ ] Phase 5: Create ripper container
- [ ] Phase 5: Configure ripper LXC config
- [ ] Phase 5: Install MakeMKV
- [ ] Phase 5: Test disc detection and ripping
- [ ] Phase 6: Save installation scripts for future use
- [ ] Phase 7: Document lessons learned

### Future Enhancements

Once basic pipeline works:

1. **Automation**:
   - Systemd service to watch /mnt/storage/staging/ for new files
   - Automatic transcoding of new rips
   - Move transcoded files to appropriate directories
   - Notification when complete

2. **Tdarr Integration**:
   - Web UI for transcoding management
   - Distributed workers across multiple containers
   - Health monitoring and queue management

3. **Media Server**:
   - Jellyfin container (unprivileged, GPU access for playback transcoding)
   - Read-only mount to /mnt/storage/movies/ and /mnt/storage/tv/

4. **Monitoring**:
   - Prometheus metrics for transcoding progress
   - Grafana dashboards for GPU utilization
   - Alerts for failed jobs

## References

- Community Scripts: https://community-scripts.github.io/ProxmoxVE/scripts
- Proxmox LXC Documentation: https://pve.proxmox.com/wiki/Linux_Container
- MakeMKV Forum: https://www.makemkv.com/forum/
- Jellyfin Guide: https://forum.jellyfin.org/t-from-disc-to-drive-a-beginner-s-guide-to-preparing-your-media-for-jellyfin
- LinuxServer.io Conventions: https://docs.linuxserver.io/general/understanding-puid-and-pgid

## Appendix: Community Script Patterns Learned

### Pattern 1: Dynamic User Detection
```bash
# Instead of hardcoding "root"
adduser $(id -u -n) video
```

### Pattern 2: Dynamic GID Synchronization
```bash
VIDEO_GID=$(getent group video | cut -d: -f3)
RENDER_GID=$(getent group render | cut -d: -f3)
if [[ -n "$VIDEO_GID" && -n "$RENDER_GID" ]]; then
  sed -i "s/^video:x:[0-9]*:/video:x:$VIDEO_GID:/" /etc/group
  sed -i "s/^render:x:[0-9]*:/render:x:$RENDER_GID:/" /etc/group
fi
```

### Pattern 3: Privileged vs Unprivileged Detection
```bash
if [[ "$CTTYPE" == "0" ]]; then
  # Privileged: fix permissions
  chgrp video /dev/dri
  chmod 660 /dev/dri/*
else
  # Unprivileged: use device mapping
  # (configured via build.func)
fi
```

### Pattern 4: Error Handling
```bash
set -Eeo pipefail
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
```

### Pattern 5: Service Management
```bash
# Create systemd service
cat <<EOF >/etc/systemd/system/myapp.service
[Unit]
Description=My App
After=network.target

[Service]
User=media
Group=media
ExecStart=/opt/myapp/run.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now myapp
```

---

**End of Plan Document**

Ready to execute when you are. Start with Phase 1 (host setup) and work through systematically.