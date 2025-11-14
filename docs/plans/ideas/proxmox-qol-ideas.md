# Proxmox VE Quality of Life Scripts - Recommendations

Based on review of the [Proxmox VE Community Scripts](https://github.com/community-scripts/ProxmoxVE) repository, here are quality of life improvements worth implementing for your homelab.

## High Priority - Immediate Value

### 1. **Post-Install Configuration** (`post-pve-install.sh`)
**What it does:**
- Corrects APT repository sources (Debian/Trixie for PVE 9)
- Disables enterprise repository (subscription not needed)
- Enables no-subscription repository
- Removes subscription nag from web UI and mobile UI
- Configures Ceph repositories (disabled by default)
- Adds pvetest repository (disabled by default)
- Manages high availability services for single-node setups
- Handles migration from legacy `.list` to modern deb822 `.sources` format

**Why you need it:** Essential first-run script after Proxmox installation. Fixes repos and removes annoying subscription popups.

**Implementation:** Adapt the repo management and subscription nag removal for your setup.

---

### 2. **Kernel Management**

#### **Kernel Cleaning** (`kernel-clean.sh`)
- Lists old kernel versions
- Allows selection of specific kernels to remove
- Updates GRUB after removal
- Frees up `/boot` space

#### **Kernel Pinning** (`kernel-pin.sh`)
- Pin specific kernel version to prevent auto-upgrades
- Useful when newer kernels have hardware compatibility issues
- Easy unpin capability

**Why you need it:** Prevent `/boot` partition from filling up, control kernel versions for stability.

---

### 3. **Container Management**

#### **Update All Containers** (`update-lxcs.sh`)
- Updates all LXC containers with one command
- Supports multiple distros: Ubuntu, Debian, Fedora, Alpine, Arch, openSUSE
- Shows disk usage before updating
- Can exclude specific containers
- Auto-starts stopped containers (then stops them again)
- Reports which containers need reboots
- Provides cron scheduling option (`cron-update-lxcs.sh`)

#### **Clean Containers** (`clean-lxcs.sh`)
- Clears logs, cache, temp files
- Runs autoremove/autoclean
- Updates package lists
- Frees up significant disk space

**Why you need it:** Automate container maintenance, prevent disk bloat, keep everything updated.

---

### 4. **Host Backup** (`host-backup.sh`)
- Interactive backup of host configuration directories
- Default: backs up `/etc/` (all Proxmox configs)
- Can backup any directory: `/var/lib/pve-cluster/`, `/root/`, etc.
- Creates timestamped tar.gz archives
- Selective file/directory backup

**Why you need it:** Critical for disaster recovery. Backup your PVE configuration before major changes.

**Recommendation:** Create automated backup script that runs weekly via cron.

---

### 5. **Storage Optimization** (`fstrim.sh`)
- Runs fstrim on all running containers
- Reclaims unused blocks on SSDs
- Can temporarily start stopped containers for trimming
- Shows before/after disk usage

**Why you need it:** Essential for SSD longevity and performance. Should run weekly.

---

## Medium Priority - Performance & Monitoring

### 6. **CPU Scaling Governor** (`scaling-governor.sh`)
- View/change CPU frequency scaling policy
- Options: performance, powersave, ondemand, conservative, schedutil
- Can persist across reboots via crontab
- Useful for either max performance or power savings

**Why useful:** Control performance vs power consumption trade-offs.

**Current system:** Your N100 likely uses `schedutil` by default, which is reasonable.

---

### 7. **Microcode Updates** (`microcode.sh`)
- Fetches latest Intel/AMD microcode from Debian repos
- Shows current microcode revision
- Interactive selection of microcode package to install
- Critical for security patches and CPU bug fixes

**Why useful:** Keep CPU microcode current for security and stability.

---

### 8. **Monitor All** (`monitor-all.sh`)
- Tag-based monitoring system
- Auto-restarts unresponsive VMs/containers with `mon-restart` tag
- For VMs: uses QEMU guest agent ping
- For containers: uses network ping
- Configurable exclusions
- Runs as systemd service

**Why useful:** Auto-recovery for critical services. Better than manual monitoring.

**Recommendation:** Implement for your core services (Jellyfin, Pi-hole, etc.)

---

### 9. **Hardware Acceleration** (`hw-acceleration.sh`)
- Adds Intel/AMD GPU passthrough to privileged containers
- Configures `/dev/dri` device access
- Installs appropriate drivers (VAAPI, non-free drivers)
- Essential for media transcoding in Plex/Jellyfin/Frigate

**Why useful:** If you plan to run media services that need hardware transcoding.

---

## Lower Priority - Specific Use Cases

### 10. **Network Configuration**

#### **NIC Offloading Fix** (`nic-offloading-fix.sh`)
- Disables problematic offload features on Intel e1000e/e1000 NICs
- Fixes packet corruption and network instability issues
- Creates systemd service to persist settings
- Known issue with certain Intel NICs under high load

**Why useful:** Only if you experience network issues with Intel NICs.

---

### 11. **Add-ons for Containers**

#### **Tailscale Integration** (`add-tailscale-lxc.sh`)
- Adds Tailscale to existing containers
- Configures TUN device access
- Supports multiple distros

#### **NetBird Integration** (`add-netbird-lxc.sh`)
- Similar to Tailscale addon
- Alternative VPN mesh solution

**Why useful:** You're already using Tailscale on host. Could be useful for individual container access.

---

### 12. **FSTRIM Automation**
Already covered above, but recommend:
```bash
# Add to crontab
0 3 * * 0 /path/to/fstrim.sh
```

---

## Scripts NOT Relevant for Your Setup

- **Ceph management** - You're not using Ceph storage
- **Cluster HA management** - Single node setup
- **PBS/PMG post-install** - You're using PVE, not Backup Server or Mail Gateway
- **Container restore tools** - Useful later, not immediate priority
- **USB passthrough** - Wait until you have a specific need

---

## Recommended Implementation Order

1. **Week 1: Essential Setup**
   - Run post-PVE-install script
   - Set up host backup (manual first, then automate)
   - Clean up old kernels

2. **Week 2: Container Management**
   - Deploy update-lxcs script
   - Create update schedule (manual or cron)
   - Deploy clean-lxcs script

3. **Week 3: Optimization**
   - Set up fstrim automation
   - Review CPU scaling governor
   - Update microcode

4. **Week 4: Monitoring**
   - Deploy monitor-all for critical services
   - Test auto-restart functionality

5. **Future: As Needed**
   - Hardware acceleration (when you deploy media services)
   - NIC offloading fix (if you experience issues)
   - Container Tailscale (if you need per-container VPN)

---

## Key Takeaways

**Must-have scripts:**
1. Post-install configuration
2. Kernel management (clean + pin)
3. Container updates automation
4. Host backup
5. FSTRIM for SSD health

**Nice-to-have:**
1. Monitor-all for auto-recovery
2. CPU governor tuning
3. Microcode updates
4. Container cleanup automation

**Situational:**
1. Hardware acceleration
2. NIC offloading fixes
3. Per-container VPN access

---

## Implementation Strategy

Rather than copying scripts directly, consider:

1. **Create your own wrapper scripts** inspired by these
2. **Use systemd timers** instead of cron for better logging
3. **Add notification integration** (ntfy, email, etc.)
4. **Version control everything** in this repo
5. **Test on non-critical containers first**

---

## Resources

- **Repository:** https://github.com/community-scripts/ProxmoxVE
- **Website:** https://community-scripts.github.io/Proxmox/
- **Local clone:** `/tmp/ProxmoxVE/`

---

## Next Steps

1. Review this document and prioritize what's most useful
2. Test scripts in your environment before automation
3. Create custom versions adapted to your specific needs
4. Document your implementations in this repo
5. Set up monitoring/alerting for automated tasks
