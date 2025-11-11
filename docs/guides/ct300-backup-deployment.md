# CT300 Backup Container Deployment Guide

**Goal**: Deploy first IaC-managed container with Terraform + Ansible for automated backups

---

## Overview

This guide walks through deploying **CT300** (backup container) using:
- **Terraform**: Creates the LXC container
- **Ansible**: Configures restic backups + Backrest UI
- **Backblaze B2**: Cloud backup storage

### What Gets Backed Up

**Included** (from `/mnt/storage`):
- ✅ `photos/`, `Photos/` - Personal photos
- ✅ `backups/`, `backup-bbg/`, `ani-backup/` - Existing backups  
- ✅ `e-books/`, `audiobooks/` - Digital library
- ✅ `downloads/`, `images/`, `random/` - Other data

**Excluded** (too large/replaceable):
- ❌ `media/` - Media pipeline (staging/ripped)
- ❌ `Movies/`, `tv/` - Large media files
- ❌ `temp/`, `lost+found/` - Temporary files

---

## Prerequisites

### 1. Backblaze B2 Setup

1. Sign up at [backblaze.com](https://www.backblaze.com/b2/sign-up.html)
2. Create application key:
   - Go to **App Keys** → **Add a New Application Key**
   - Name: "homelab-backups"
   - Access: Read and Write
   - Save **Account ID** and **Application Key**

3. Create B2 bucket:
   - Go to **Buckets** → **Create a Bucket**
   - Name: `homelab-data`
   - Files: **Private**
   - Encryption: **Disabled** (restic encrypts)
   - Object Lock: **Disabled**

4. Generate restic password:
   ```bash
   openssl rand -base64 32
   # Save this password securely!
   ```

### 2. Proxmox Template

Verify Debian 12 template exists:

```bash
ssh homelab
pveam list local | grep debian-12

# If not found, download it:
pveam update
pveam download local debian-12-standard_12.7-1_amd64.tar.zst
```

### 3. Tools Installed

On your workstation:

```bash
# Terraform
terraform version  # Should be >= 1.5.0

# Ansible
ansible --version  # Should be >= 2.9

# SSH access to Proxmox
ssh homelab "echo 'Connected!'"
```

---

## Step 1: Configure Secrets

### Terraform Secrets

```bash
cd ~/dev/homelab-notes/terraform

# Copy example and edit
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Fill in:
```hcl
proxmox_password = "your_proxmox_root_password"
ssh_public_key = "ssh-rsa AAAAB3... your_key"  # Optional
```

### Ansible Secrets

```bash
cd ~/dev/homelab-notes/ansible/vars

# Copy example and edit
cp backup_secrets.yml.example backup_secrets.yml
nano backup_secrets.yml
```

Fill in:
```yaml
vault_b2_account_id: "your_b2_account_id"
vault_b2_account_key: "your_b2_application_key"
vault_b2_bucket_data: "homelab-data"
vault_restic_password_data: "your_generated_restic_password"
```

### Encrypt Ansible Secrets

```bash
# Encrypt the file
ansible-vault encrypt backup_secrets.yml
# Enter a vault password (store in password manager!)

# Save vault password for later
echo "your_vault_password" > ~/.vault_pass
chmod 600 ~/.vault_pass

# Test decryption
ansible-vault view backup_secrets.yml --vault-password-file ~/.vault_pass
```

---

## Step 2: Deploy with Terraform

```bash
cd ~/dev/homelab-notes/terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply (create container)
terraform apply
# Type 'yes' when prompted
```

**Expected output:**
```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

backup_container_id = 300
backup_container_ip = "dhcp"
```

### Verify Container Created

```bash
ssh homelab "pct list | grep 300"
# Should show: 300  running  backup

# Get IP address
ssh homelab "pct exec 300 -- hostname -I"
# Note this IP for next step
```

---

## Step 3: Configure Storage Mount

The container needs `/mnt/storage` mounted from the host:

```bash
ssh homelab

# Mount storage in container
pct set 300 -mp0 /mnt/storage,mp=/mnt/storage

# Restart container to apply
pct stop 300
pct start 300

# Verify mount
pct exec 300 -- df -h /mnt/storage
# Should show: /mnt/storage  35T  4.1T  29T  13% /mnt/storage
```

---

## Step 4: Configure with Ansible

```bash
cd ~/dev/homelab-notes

# Set container IP (from Step 2)
export CT300_IP="192.168.1.XXX"  # Replace with actual IP

# Run Ansible playbook
ansible-playbook ansible/playbooks/ct300-backup.yml \
  --vault-password-file ~/.vault_pass
```

**What this does:**
1. Installs restic binary
2. Creates backup scripts
3. Sets up systemd timers (daily backups)
4. Initializes B2 repository
5. Configures retention policies

**Expected output:**
```
PLAY RECAP *************************************************************
ct300-backup : ok=XX  changed=XX  unreachable=0  failed=0  skipped=0
```

---

## Step 5: Test Backup

### Run Initial Backup

```bash
# Start backup manually
ssh homelab "pct exec 300 -- systemctl start restic-backup-data.service"

# Watch progress
ssh homelab "pct exec 300 -- journalctl -u restic-backup-data.service -f"
```

**First backup will take a while** (uploads all data).

### Verify Backup Succeeded

```bash
# List snapshots
ssh homelab "pct exec 300 -- /etc/restic/scripts/maintenance.sh snapshots data"

# View repository stats
ssh homelab "pct exec 300 -- /etc/restic/scripts/maintenance.sh stats data"
```

### Test Restore

```bash
# Restore to temporary directory
ssh homelab "pct exec 300 -- /etc/restic/scripts/restore.sh -p data -t /tmp/restore-test"

# Verify files
ssh homelab "pct exec 300 -- ls -lh /tmp/restore-test/mnt/storage/photos"

# Clean up
ssh homelab "pct exec 300 -- rm -rf /tmp/restore-test"
```

---

## Step 6: (Optional) Install Backrest UI

Coming soon - Backrest provides a web interface for browsing snapshots and restoring files.

For now, you have:
- ✅ Automated daily backups
- ✅ Command-line tools for restore
- ✅ Full IaC control

---

## Monitoring

### Check Backup Status

```bash
# View timer status
ssh homelab "pct exec 300 -- systemctl status restic-backup-data.timer"

# View last backup log
ssh homelab "pct exec 300 -- ls -lt /var/log/restic/backup-data-*.log | head -1"

# List all snapshots
ssh homelab "pct exec 300 -- /etc/restic/scripts/maintenance.sh snapshots data"
```

### Check B2 Usage

1. Login to Backblaze: https://secure.backblaze.com/
2. Go to **Buckets** → `homelab-data`
3. View size and cost estimate

**Estimated costs** (B2 pricing):
- Storage: $0.005/GB/month
- Download: $0.01/GB (first 3x storage free)

Example: 100GB backup = $0.50/month

---

## Troubleshooting

### Container Won't Start

```bash
# Check status
ssh homelab "pct status 300"

# View logs
ssh homelab "journalctl -u pve-container@300.service -n 50"

# Try starting manually
ssh homelab "pct start 300"
```

### No Network in Container

```bash
# Check IP
ssh homelab "pct exec 300 -- ip addr"

# Restart container
ssh homelab "pct stop 300 && pct start 300"

# Check DHCP on router
```

### Backup Fails

```bash
# View backup logs
ssh homelab "pct exec 300 -- journalctl -u restic-backup-data.service -n 100"

# Test B2 credentials manually
ssh homelab "pct exec 300 -- bash"
source /etc/restic/data.env
restic snapshots  # Should list snapshots or show auth error
```

### Storage Not Mounted

```bash
# Check mount
ssh homelab "pct exec 300 -- mount | grep storage"

# Remount
ssh homelab "pct set 300 -mp0 /mnt/storage,mp=/mnt/storage"
ssh homelab "pct stop 300 && pct start 300"
```

---

## Daily Operations

### Manual Backup

```bash
ssh homelab "pct exec 300 -- systemctl start restic-backup-data.service"
```

### Restore Single File

```bash
# Find file in snapshot
ssh homelab "pct exec 300 -- bash"
source /etc/restic/data.env
restic find important-document.pdf

# Restore to temp location
/etc/restic/scripts/restore.sh -p data -t /tmp/restore

# Copy restored file out
cp /tmp/restore/mnt/storage/documents/important-document.pdf /root/
```

### Check Repository Health

```bash
ssh homelab "pct exec 300 -- /etc/restic/scripts/maintenance.sh check data"
```

---

## Cleanup (If Needed)

### Remove Container

```bash
cd ~/dev/homelab-notes/terraform

# Destroy via Terraform
terraform destroy -target=proxmox_virtual_environment_container.backup

# Or manually
ssh homelab "pct stop 300 && pct destroy 300"
```

### Delete B2 Bucket

1. Login to Backblaze
2. **Buckets** → `homelab-data` → **Delete Bucket**
3. Confirm deletion

**Warning**: This deletes all backups!

---

## Next Steps

- [x] Deploy CT300 with Terraform
- [x] Configure backups with Ansible
- [x] Test backup and restore
- [ ] Set calendar reminder for monthly restore tests
- [ ] Monitor first week of backups
- [ ] Review B2 costs after first month
- [ ] Add Backrest UI (optional)
- [ ] Deploy more IaC containers (CT301, CT302, etc.)

---

## Success Checklist

- [ ] Container created with Terraform
- [ ] Storage mounted at `/mnt/storage`
- [ ] Ansible playbook completed successfully
- [ ] First backup completed
- [ ] Snapshot visible in B2 bucket
- [ ] Test restore succeeded
- [ ] Daily timer is active

Once all checked, your IaC backup workflow is complete! 🎉

---

**Last Updated**: 2025-11-11
