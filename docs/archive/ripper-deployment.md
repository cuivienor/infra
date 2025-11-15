# CT302 Ripper Container Deployment Guide

**Container**: CT302 (ripper)  
**Purpose**: MakeMKV Blu-ray/DVD ripper with optical drive passthrough  
**Type**: IaC-managed (Terraform + Ansible)  
**Status**: ✅ **DEPLOYMENT COMPLETED - 2025-11-11**

This deployment was successful. See "Deployment History" section below for details.

---

## Deployment History

### 2025-11-11: Initial Deployment - SUCCESS ✅

**Deployment Duration**: ~20 minutes total
- **Terraform**: 5 seconds to create container
- **Ansible**: ~15 minutes (MakeMKV v1.18.2 compilation from source)

**Deployment Steps Completed**:
1. ✅ Created vault password file (repo root: `.vault_pass`)
2. ✅ Encrypted MakeMKV secrets with Ansible Vault
3. ✅ Terraform created CT302 container
4. ✅ Container received DHCP IP: 192.168.1.70
5. ✅ Updated Ansible inventory with IP
6. ✅ Ansible playbook executed successfully (50+ tasks)
7. ✅ All verification tests passed

**Issues Encountered & Resolved**:

*Issue 1: MakeMKV BIN EULA acceptance*
- **Problem**: Directory `/tmp/makemkv-build/makemkv-bin-1.18.2/tmp` didn't exist
- **Fix**: Added task to create tmp directory before EULA acceptance
- **File**: `ansible/roles/makemkv/tasks/main.yml`

*Issue 2: Container restart handler*
- **Problem**: `pct restart` command doesn't exist in Proxmox
- **Fix**: Changed to `pct stop && pct start` sequence
- **File**: `ansible/roles/optical_drive_passthrough/handlers/main.yml`

**Security Enhancements Implemented**:
- ✅ **Restricted storage mount**: Only `/mnt/storage/media/staging` mounted as `/mnt/staging`
- ✅ **Least privilege**: Ripper cannot access finished media library, photos, documents, etc.
- ✅ **Script auto-detection**: Updated `rip-disc.sh` to detect mount point automatically
- ✅ **Reduced blast radius**: Container compromise limited to staging directory only

**Final Verification Results**:
```
✅ Media user: UID 1000, GID 1000, groups: media, cdrom
✅ MakeMKV: v1.18.2 installed and functional
✅ Optical drives: /dev/sr0 and /dev/sg4 accessible
✅ Storage mount: /mnt/staging mounted correctly
✅ Script deployed: /home/media/scripts/rip-disc.sh (executable)
✅ Path detection: Script correctly detects /mnt/staging mount
```

**Container Details**:
- **CTID**: 302
- **IP Address**: 192.168.1.70
- **Hostname**: ripper
- **Resources**: 2 cores, 4GB RAM, 2GB swap, 8GB disk
- **Status**: Production ready

**Comparison with CT200**:
| Feature | CT200 (Manual) | CT302 (IaC) |
|---------|----------------|-------------|
| Storage Access | Full `/mnt/storage` | Restricted `/mnt/staging` only |
| Creation | Manual (Proxmox UI) | Terraform (5 seconds) |
| Configuration | Manual SSH | Ansible automation |
| Reproducible | ❌ No | ✅ Yes (single command) |
| Disaster Recovery | Manual rebuild | `terraform apply && ansible-playbook` |
| Version Control | ❌ No | ✅ Git-tracked |

---

## Overview (Original Deployment Guide)

This guide walks through deploying CT302, a fully IaC-managed ripper container that replicates the functionality of CT200 (ripper-new) using Terraform and Ansible.

### What Gets Deployed

- **Container**: Debian 12 LXC (privileged) with 2 cores, 4GB RAM, 8GB disk
- **Software**: MakeMKV v1.18.2 compiled from source
- **Hardware**: Optical drive passthrough (/dev/sr0, /dev/sg4)
- **User**: media (UID 1000, GID 1000) with cdrom group
- **Scripts**: rip-disc.sh for automated disc ripping
- **Storage**: Only `/mnt/storage/media/staging` mounted as `/mnt/staging` (least privilege)

---

## Prerequisites

### 1. Vault Password File

The MakeMKV beta key is stored in an encrypted Ansible Vault file. You need a vault password:

```bash
# Create vault password file (if not already created)
echo "your-secure-password-here" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

### 2. Encrypt Secrets File

The secrets file is currently unencrypted. Encrypt it before deployment:

```bash
cd ~/dev/homelab-notes/ansible
ansible-vault encrypt vars/makemkv_secrets.yml --vault-password-file ~/.vault_pass
```

To update the beta key later:

```bash
ansible-vault edit vars/makemkv_secrets.yml --vault-password-file ~/.vault_pass
```

### 3. SSH Keys

Ensure your SSH public key is in `ansible/files/ssh-keys/laptop.pub` (should already exist).

---

## Deployment Steps

### Step 1: Create Container with Terraform

```bash
cd ~/dev/homelab-notes/terraform

# Initialize Terraform (if not already done)
terraform init

# Review the plan
terraform plan

# Create the container
terraform apply
```

**Expected output:**
- Container CT302 created
- DHCP IP address assigned
- Container started

### Step 2: Get Container IP Address

The container uses DHCP, so we need to discover its IP:

```bash
ssh homelab "pct exec 302 -- ip -4 addr show eth0 | grep inet"
```

**Example output:**
```
inet 192.168.1.XX/24 brd 192.168.1.255 scope global dynamic eth0
```

### Step 3: Update Ansible Inventory

Edit `ansible/inventory/hosts.yml` and update the ct302 IP address:

```yaml
ripper_containers:
  hosts:
    ct302:
      ansible_host: 192.168.1.XX  # Replace with actual IP from Step 2
      ansible_user: root
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
      container_id: 302
```

### Step 4: Test Ansible Connectivity

```bash
cd ~/dev/homelab-notes/ansible
ansible ct302 -m ping
```

**Expected output:**
```
ct302 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### Step 5: Run Ansible Playbook

```bash
cd ~/dev/homelab-notes/ansible
ansible-playbook playbooks/ct302-ripper.yml --vault-password-file ~/.vault_pass
```

**This will:**
1. Configure system (timezone, locale, SSH keys)
2. Create media user with cdrom group
3. Install MakeMKV build dependencies
4. Download, compile, and install MakeMKV v1.18.2
5. Configure MakeMKV settings (beta key, defaults)
6. Deploy rip-disc.sh script
7. Configure optical drive passthrough on host
8. Restart container (if needed)
9. Verify all components

**Duration:** ~15-20 minutes (MakeMKV compilation takes time)

---

## Verification

After deployment completes, verify everything works:

### 1. Check Container Status

```bash
ssh homelab "pct list | grep 302"
```

### 2. Enter Container

```bash
ssh homelab "pct enter 302"
```

### 3. Verify Media User

```bash
id media
# Expected: uid=1000(media) gid=1000(media) groups=1000(media),24(cdrom)
```

### 4. Verify MakeMKV Installation

```bash
su - media
makemkvcon info
# Expected: MakeMKV v1.18.2 linux(x64-release) started
```

### 5. Verify Optical Drive Access

```bash
ls -la /dev/sr0 /dev/sg4
# Expected: Both devices should exist
```

### 6. Test with Disc (if available)

```bash
su - media
makemkvcon info disc:0
# Should show disc information
```

### 7. Verify Script Deployment

```bash
su - media
ls -la ~/scripts/
cat ~/scripts/rip-disc.sh | head -20
```

### 8. Verify Storage Mount

```bash
ls -la /mnt/staging/1-ripped/
# Should show movies/ and tv/ directories
```

**Note**: Container mounts `/mnt/storage/media/staging` from host as `/mnt/staging` for security (least privilege access).

---

## Post-Deployment Configuration

### Update MakeMKV Beta Key (Monthly)

The beta key expires monthly. Get the latest from:
https://forum.makemkv.com/forum/viewtopic.php?t=1053

Update the encrypted secrets file:

```bash
cd ~/dev/homelab-notes/ansible
ansible-vault edit vars/makemkv_secrets.yml --vault-password-file ~/.vault_pass
# Update makemkv_beta_key value
```

Re-run the playbook (only MakeMKV config tasks will change):

```bash
ansible-playbook playbooks/ct302-ripper.yml --vault-password-file ~/.vault_pass --tags makemkv
```

### Upgrade MakeMKV Version

When a new MakeMKV version is released:

1. Update version in `ansible/roles/makemkv/defaults/main.yml`:
   ```yaml
   makemkv_version: "1.18.3"  # or newer
   ```

2. Re-run playbook:
   ```bash
   ansible-playbook playbooks/ct302-ripper.yml --vault-password-file ~/.vault_pass --tags makemkv
   ```

The role will detect the version mismatch and recompile.

---

## Usage

### Ripping a Movie

```bash
ssh homelab "pct enter 302"
su - media
cd ~
./scripts/rip-disc.sh movie "Movie Name"
```

**Output** (in container): `/mnt/staging/1-ripped/movies/Movie_Name_2025-11-11/`  
**Output** (on host): `/mnt/storage/media/staging/1-ripped/movies/Movie_Name_2025-11-11/`

### Ripping a TV Show

```bash
ssh homelab "pct enter 302"
su - media
cd ~
./scripts/rip-disc.sh show "Show Name" "S01 Disc1"
```

**Output** (in container): `/mnt/staging/1-ripped/tv/Show_Name/S01_Disc1_2025-11-11/`  
**Output** (on host): `/mnt/storage/media/staging/1-ripped/tv/Show_Name/S01_Disc1_2025-11-11/`

---

## Troubleshooting

### MakeMKV Can't Access Disc

**Symptom:** `Failed to open disc`

**Solution:** Verify optical drive passthrough:

```bash
# On container
ls -la /dev/sr0 /dev/sg4

# On host, check container config
ssh homelab "cat /etc/pve/lxc/302.conf | grep lxc"
```

Expected in config:
```
lxc.cgroup2.devices.allow: c 11:0 rwm
lxc.cgroup2.devices.allow: c 21:4 rwm
lxc.mount.entry: /dev/sr0 dev/sr0 none bind,optional,create=file
lxc.mount.entry: /dev/sg4 dev/sg4 none bind,optional,create=file
```

If missing, re-run Ansible with passthrough tag:
```bash
ansible-playbook playbooks/ct302-ripper.yml --vault-password-file ~/.vault_pass --tags optical
```

### Beta Key Expired

**Symptom:** MakeMKV shows "Evaluation version expired"

**Solution:** Update beta key (see Post-Deployment Configuration above)

### Compilation Fails

**Symptom:** Ansible fails during MakeMKV build

**Solution:**
1. SSH into container: `ssh homelab "pct enter 302"`
2. Check `/tmp/makemkv-build/` for error logs
3. Verify build dependencies installed: `dpkg -l | grep -E "(build-essential|qt5|libavcodec)"`
4. Re-run playbook with verbose output: `ansible-playbook ... -vvv`

### Permission Denied on /mnt/staging

**Symptom:** Can't write to `/mnt/staging` as media user

**Solution:** Check ownership on host:
```bash
ssh homelab "ls -ld /mnt/storage/media/staging/"
# Should be: drwxrwxr-x media media
```

Fix if needed:
```bash
ssh homelab "chown -R media:media /mnt/storage/media/staging/"
```

---

## Comparison: CT200 vs CT302

| Feature | CT200 (Manual) | CT302 (IaC) |
|---------|---------------|-------------|
| **Creation** | Manual via Proxmox UI | Terraform |
| **Configuration** | Manual SSH commands | Ansible playbook |
| **MakeMKV Install** | Manual compilation | Automated via role |
| **Settings** | Manual config file | Ansible Vault secrets |
| **Scripts** | Manual SCP | Ansible copy module |
| **Reproducible** | ❌ No | ✅ Yes |
| **Version Control** | ❌ No | ✅ Yes |
| **Disaster Recovery** | Manual rebuild | Single command |
| **Updates** | Manual | Update version, re-run playbook |

---

## Files Reference

**Terraform:**
- `terraform/ct302-ripper.tf` - Container definition

**Ansible:**
- `ansible/playbooks/ct302-ripper.yml` - Main playbook
- `ansible/roles/makemkv/` - MakeMKV installation role
- `ansible/roles/optical_drive_passthrough/` - Device passthrough role
- `ansible/roles/common/` - Common configuration (media user)
- `ansible/vars/makemkv_secrets.yml` - Encrypted beta key
- `ansible/inventory/hosts.yml` - Inventory (update IP here)

**Scripts:**
- `scripts/media/rip-disc.sh` - Ripping automation script

---

## Next Steps

Once CT302 is deployed and verified:

1. **Test thoroughly** with actual disc ripping
2. **Compare output** with CT200 to ensure parity
3. **Document any differences** or issues
4. **Plan cutover** from CT200 → CT302
5. **Decommission CT200** once confident in CT302

---

## Rollback

If issues occur, CT200 is still running and untouched. Simply:

1. Continue using CT200 for ripping
2. Destroy CT302: `terraform destroy` (select ct302 only)
3. Fix issues and retry deployment

---

**Deployment Date**: TBD  
**Last Updated**: 2025-11-11  
**Status**: Ready for deployment
