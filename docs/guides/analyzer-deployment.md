# CT303: Analyzer Container Deployment Guide

**Date**: 2025-11-11  
**Purpose**: Deploy IaC-managed analyzer container for media analysis and remuxing  
**Replaces**: CT202 (manual analyzer container)

---

## Overview

CT303 is the IaC-managed version of the analyzer container, responsible for:
- **Media file analysis** - Duration, size, resolution, track detection
- **Duplicate detection** - Finding potential duplicate files
- **Remuxing** - Removing non-English/Bulgarian tracks
- **Organization** - Preparing files for transcoding and library import
- **Pipeline promotion** - Moving files between staging directories

---

## Container Specifications

| Property | Value |
|----------|-------|
| **CTID** | 303 |
| **Hostname** | analyzer |
| **IP Address** | 192.168.1.73/24 (static) |
| **OS** | Debian 12 (Bookworm) |
| **Type** | Privileged (for storage access) |
| **CPU** | 2 cores, 1024 units (medium priority) |
| **Memory** | 4GB RAM, 2GB swap |
| **Disk** | 12GB (OS + tools + temp files) |
| **Storage Mount** | `/mnt/storage/media/staging` → `/mnt/staging` |
| **Tags** | `media`, `iac`, `analyzer` |

---

## Security Design

Following the **least privilege principle** from CT302:

- **Limited storage access**: Only `/mnt/storage/media/staging` mounted (not full `/mnt/storage`)
- **No hardware passthrough**: Pure software operations
- **Restricted operations**: Can only access staging pipeline directories

---

## Prerequisites

1. **Terraform initialized** in `terraform/` directory
2. **SSH access configured** for root to containers
3. **Ansible vault password** in `.vault_pass` (if using encrypted secrets)
4. **CT202** (old analyzer) stopped or not conflicting

---

## Deployment Steps

### Step 1: Deploy Container with Terraform

```bash
cd ~/dev/homelab-notes/terraform

# Review the configuration
terraform plan -target=proxmox_virtual_environment_container.analyzer

# Deploy the container
terraform apply -target=proxmox_virtual_environment_container.analyzer

# Note the output IP address (should be 192.168.1.73)
```

**Expected output:**
```
analyzer_container_id = 303
analyzer_container_ip = "192.168.1.73/24"
```

### Step 2: Wait for Container to Boot

```bash
# Wait for container to be ready (30-60 seconds)
ssh root@192.168.1.56 "pct list | grep 303"

# Test SSH connectivity
ssh root@192.168.1.73 "echo 'Container is accessible'"
```

### Step 3: Configure with Ansible

```bash
cd ~/dev/homelab-notes/ansible

# Test connectivity
ansible ct303 -m ping

# Deploy full configuration (common role + analyzer role)
ansible-playbook playbooks/ct303-analyzer.yml

# Or run with specific tags:
# ansible-playbook playbooks/ct303-analyzer.yml --tags common,analyzer
```

**What this does:**
1. Creates `media` user (UID 1000)
2. Installs packages: mkvtoolnix, mediainfo, jq, bc, rsync
3. Deploys 6 media scripts to `/home/media/scripts/`
4. Configures environment variables
5. Verifies installation

### Step 4: Verify Deployment

```bash
# Run verification tasks
ansible-playbook playbooks/ct303-analyzer.yml --tags verify

# Manual verification
ssh root@192.168.1.56 "pct enter 303"

# Inside container
su - media
ls -la ~/scripts/
mkvmerge --version
mediainfo --version
ls -la /mnt/staging/
```

**Verify:**
- ✅ 6 scripts deployed to `/home/media/scripts/`
- ✅ mkvtoolnix, mediainfo, jq installed
- ✅ `/mnt/staging/` mount accessible
- ✅ Media user has correct permissions
- ✅ Scripts are executable

---

## Installed Tools

| Tool | Version | Purpose |
|------|---------|---------|
| **mkvtoolnix** | 74.0.0+ | MKV remuxing and manipulation |
| **mediainfo** | 23.04+ | Media file analysis |
| **jq** | 1.6+ | JSON processing for scripts |
| **bc** | Latest | Calculator for size/duration calculations |
| **rsync** | Latest | File synchronization |

### Optional: FileBot

FileBot is **not installed by default**. To enable:

```yaml
# In playbook or as extra var
media_analyzer_install_filebot: true
```

Then re-run Ansible:
```bash
ansible-playbook playbooks/ct303-analyzer.yml -e "media_analyzer_install_filebot=true"
```

---

## Deployed Scripts

All scripts located in `/home/media/scripts/`:

### 1. analyze-media.sh
**Purpose**: Analyze MKV files in a directory

**Usage:**
```bash
~/scripts/analyze-media.sh /mnt/staging/1-ripped/movies/Movie_Name/
```

**Features:**
- Lists all MKV files with size, duration, resolution
- Detects potential duplicate files (similar duration)
- Categorizes as main features vs extras
- Saves analysis report to `.analysis.txt`

### 2. organize-and-remux-movie.sh
**Purpose**: Process movies from 1-ripped → 2-remuxed

**Usage:**
```bash
~/scripts/organize-and-remux-movie.sh /mnt/staging/1-ripped/movies/Movie_Name_2024-11-10/
```

**Features:**
- Analyzes and categorizes files automatically
- Remuxes to keep only English/Bulgarian tracks
- Creates main folder + extras/ subfolder
- Shows space savings from track removal

### 3. organize-and-remux-tv.sh
**Purpose**: Process TV shows from 1-ripped → 2-remuxed

**Usage:**
```bash
~/scripts/organize-and-remux-tv.sh "Show Name" 01
```

**Features:**
- Handles TV series by season
- Remuxes with language filtering
- Organizes by season structure

### 4. promote-to-ready.sh
**Purpose**: Move files from 3-transcoded → 4-ready

**Usage:**
```bash
~/scripts/promote-to-ready.sh /mnt/staging/3-transcoded/movies/Movie_Name/
```

**Features:**
- Prepares files for final library import
- Preserves directory structure

### 5. filebot-process.sh
**Purpose**: FileBot automation for library organization

**Usage:**
```bash
~/scripts/filebot-process.sh /mnt/staging/4-ready/movies/Movie_Name/
```

**Requirements:** FileBot must be installed

### 6. fix-current-names.sh
**Purpose**: Utility to fix naming issues in existing files

---

## Typical Workflow

### Phase 1: Analyze Ripped Media
```bash
pct enter 303
su - media

# Analyze what was ripped
~/scripts/analyze-media.sh /mnt/staging/1-ripped/movies/Movie_2024-11-10/
```

### Phase 2: Organize and Remux
```bash
# Process movie
~/scripts/organize-and-remux-movie.sh /mnt/staging/1-ripped/movies/Movie_2024-11-10/

# OR for TV shows
~/scripts/organize-and-remux-tv.sh "Show Name" 01
```

**Result**: Files in `/mnt/staging/2-remuxed/` ready for transcoding

### Phase 3: After Transcoding (on CT201)
Once CT201 finishes transcoding to `3-transcoded/`:

```bash
# Promote to ready stage
~/scripts/promote-to-ready.sh /mnt/staging/3-transcoded/movies/Movie_Name/
```

### Phase 4: Import to Library (optional)
```bash
# Use FileBot for automated organization
~/scripts/filebot-process.sh /mnt/staging/4-ready/movies/Movie_Name/
```

---

## Verification Checklist

- [ ] Container created with CTID 303
- [ ] Container accessible at 192.168.1.73
- [ ] Media user created (UID 1000)
- [ ] All 6 scripts deployed and executable
- [ ] mkvtoolnix installed (check with `mkvmerge --version`)
- [ ] mediainfo installed (check with `mediainfo --version`)
- [ ] jq installed (check with `jq --version`)
- [ ] `/mnt/staging/` mount accessible
- [ ] Can list files in `/mnt/staging/1-ripped/`
- [ ] Scripts run without errors

---

## Troubleshooting

### Container won't start
```bash
# Check container status
ssh root@192.168.1.56 "pct status 303"

# Check container config
ssh root@192.168.1.56 "cat /etc/pve/lxc/303.conf"

# Start manually if needed
ssh root@192.168.1.56 "pct start 303"
```

### SSH connection fails
```bash
# Check if container has network
ssh root@192.168.1.56 "pct exec 303 -- ip addr show eth0"

# Manually configure network if needed
ssh root@192.168.1.56 "pct exec 303 -- dhclient eth0"
```

### Storage mount not accessible
```bash
# Check mount from host
ssh root@192.168.1.56 "ls -la /mnt/storage/media/staging/"

# Check mount in container
ssh root@192.168.1.73 "ls -la /mnt/staging/"

# Verify LXC config includes mount
ssh root@192.168.1.56 "grep mp0 /etc/pve/lxc/303.conf"
```

### Scripts fail with permission errors
```bash
# Check media user ownership
ssh root@192.168.1.73 "ls -la /home/media/scripts/"

# Fix ownership if needed
ssh root@192.168.1.73 "chown -R media:media /home/media/scripts/"
ssh root@192.168.1.73 "chmod +x /home/media/scripts/*.sh"
```

### Tools not found
```bash
# Re-run Ansible to install packages
ansible-playbook playbooks/ct303-analyzer.yml --tags analyzer

# Or manually install
ssh root@192.168.1.73 "apt update && apt install -y mkvtoolnix mediainfo jq bc"
```

---

## Migration from CT202

### Comparison: CT202 vs CT303

| Feature | CT202 (Manual) | CT303 (IaC) |
|---------|----------------|-------------|
| IP Address | 192.168.1.72 (DHCP) | 192.168.1.73 (static) |
| Storage Mount | `/mnt/storage` (full) | `/mnt/staging` (restricted) |
| Management | Manual configuration | Terraform + Ansible |
| Reproducibility | Manual steps | Fully automated |
| Security | Full storage access | Least privilege |
| Documentation | Setup guide | IaC definitions |

### Migration Process (When Ready)

1. **Test CT303 thoroughly** with existing media
2. **Stop CT202**: `pct stop 202`
3. **Update any external references** to use CT303 IP (192.168.1.73)
4. **Remove CT202** after validation period: `pct destroy 202`

**Note**: Do not rush migration. Keep CT202 running until CT303 is fully validated.

---

## Next Steps

1. ✅ Deploy CT303
2. ✅ Verify all scripts work
3. 🔲 Test analyze-media.sh on existing ripped media
4. 🔲 Test organize-and-remux-movie.sh on a sample movie
5. 🔲 Test full pipeline from rip → analyze → remux → transcode → promote
6. 🔲 Update any scripts or documentation referencing CT202
7. 🔲 Plan cutover from CT202 to CT303

---

## Related Documentation

- **Terraform config**: `terraform/ct303-analyzer.tf`
- **Ansible playbook**: `ansible/playbooks/ct303-analyzer.yml`
- **Ansible role**: `ansible/roles/media_analyzer/`
- **Original setup**: `docs/guides/ct202-analyzer-setup.md`
- **Media pipeline**: `docs/reference/media-pipeline-quick-reference.md`

---

**Status**: Ready for deployment  
**Time to deploy**: 10-15 minutes  
**Impact**: None on existing containers (new container with different IP)
