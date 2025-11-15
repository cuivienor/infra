# Samba Container - Setup Guide

**Created**: 2025-11-11  
**Status**: ✅ Deployed and configured

---

## Overview

This is a Samba file server providing SMB access to `/mnt/storage` for all LAN clients. Optimized for large file streaming (movie playback).

### Container Details

- **CTID**: 301
- **Hostname**: samba
- **IP Address**: 192.168.1.82/24 (static)
- **Gateway**: 192.168.1.1
- **OS**: Debian 12
- **Resources**: 1 core, 1GB RAM, 8GB disk
- **Mount**: /mnt/storage (read-write)

### Services

- **smbd**: SMB daemon (file sharing)
- **nmbd**: NetBIOS name service

---

## Access Information

### SMB Share Details

**Share Name**: `storage`  
**Path**: `/mnt/storage`  
**Username**: `media`  
**Password**: Stored encrypted in `ansible/vars/secrets.yml` (encrypted with Ansible Vault)

**Note**: The secrets.yml file is encrypted with the same vault password as backup_secrets.yml (stored in `.vault_pass`).

To view the password:
```bash
cd /home/cuiv/dev/homelab-notes/ansible
ansible-vault view vars/secrets.yml --vault-password-file=../.vault_pass
```

To edit secrets:
```bash
cd /home/cuiv/dev/homelab-notes/ansible
ansible-vault edit vars/secrets.yml --vault-password-file=../.vault_pass
```

When running playbooks:
```bash
ansible-playbook playbooks/samba.yml --vault-password-file=../.vault_pass
```

---

## Client Access

### macOS

**Finder**:
1. Go → Connect to Server (Cmd+K)
2. Server: `smb://192.168.1.82/storage`
3. Connect as: Registered User
4. Username: `media`
5. Password: (see above)

**Command line**:
```bash
mount_smbfs //media@192.168.1.82/storage /Volumes/storage
# Enter password when prompted
```

### Windows

**File Explorer**:
1. This PC → Map network drive
2. Folder: `\\192.168.1.82\storage`
3. "Connect using different credentials"
4. Username: `media`
5. Password: (see above)

**Command line**:
```cmd
net use Z: \\192.168.1.82\storage /user:media
```

### Linux

**Install cifs-utils**:
```bash
sudo apt install cifs-utils
```

**Mount**:
```bash
sudo mkdir -p /mnt/homelab-storage
sudo mount -t cifs //192.168.1.82/storage /mnt/homelab-storage \
  -o username=media,password=YOUR_PASSWORD,uid=1000,gid=1000
# Replace YOUR_PASSWORD with the password from ansible/vars/secrets.yml
```

**Persistent mount** (`/etc/fstab`):
```
//192.168.1.82/storage /mnt/homelab-storage cifs username=media,password=YOUR_PASSWORD,uid=1000,gid=1000 0 0
```

**Note**: For better security, use a credentials file instead of putting passwords in /etc/fstab:
```bash
# Create credentials file
echo "username=media" | sudo tee /root/.smbcredentials
echo "password=YOUR_PASSWORD" | sudo tee -a /root/.smbcredentials
sudo chmod 600 /root/.smbcredentials

# Use in /etc/fstab
//192.168.1.82/storage /mnt/homelab-storage cifs credentials=/root/.smbcredentials,uid=1000,gid=1000 0 0
```

---

## Verification

### Check Services

```bash
ssh root@192.168.1.82 "systemctl status smbd nmbd"
```

### List Samba Users

```bash
ssh root@192.168.1.82 "pdbedit -L"
# Should output: media:1000:
```

### Test Configuration

```bash
ssh root@192.168.1.82 "testparm -s"
```

### View Connected Clients

```bash
ssh root@192.168.1.82 "smbstatus"
```

### View Logs

```bash
ssh root@192.168.1.82 "tail -f /var/log/samba/samba.log"
```

---

## Management

### Restart Services

```bash
ssh root@192.168.1.82 "systemctl restart smbd nmbd"
```

### Update Configuration

1. Edit the template: `ansible/roles/samba/templates/smb.conf.j2`
2. Run the playbook:
   ```bash
   cd /home/cuiv/dev/homelab-notes/ansible
   ansible-playbook playbooks/samba.yml --tags config
   ```

### Change Password

1. Edit secrets:
   ```bash
   cd /home/cuiv/dev/homelab-notes/ansible
   ansible-vault edit vars/secrets.yml  # if encrypted
   # or
   nano vars/secrets.yml  # if not encrypted
   ```
2. Update `samba_media_password`
3. Run playbook:
   ```bash
   ansible-playbook playbooks/samba.yml --tags users
   ```

---

## Troubleshooting

### Can't Connect

**Check services are running**:
```bash
ssh root@192.168.1.82 "systemctl status smbd nmbd"
```

**Test from container**:
```bash
ssh root@192.168.1.82 "smbclient -L localhost -U media"
# Enter password when prompted
```

### Permission Denied

**Check mount point**:
```bash
ssh root@192.168.1.82 "ls -ld /mnt/storage"
# Should show: drwxrwxr-x media media
```

**Test as media user**:
```bash
ssh root@192.168.1.82 "sudo -u media touch /mnt/storage/test.txt"
ssh root@192.168.1.82 "sudo -u media rm /mnt/storage/test.txt"
```

### Slow Performance

**Check container resources**:
```bash
ssh root@192.168.1.56 "pct top 301"
```

**Verify socket options**:
```bash
ssh root@192.168.1.82 "testparm -s | grep socket"
```

---

## Files Created

### Terraform

- `terraform/samba.tf` - Container definition

### Ansible

- `ansible/roles/samba/tasks/main.yml` - Installation tasks
- `ansible/roles/samba/templates/smb.conf.j2` - Samba config template
- `ansible/roles/samba/handlers/main.yml` - Service handlers
- `ansible/roles/samba/defaults/main.yml` - Default variables
- `ansible/playbooks/samba.yml` - Main playbook
- `ansible/vars/secrets.yml` - Samba password (⚠️ encrypt this!)
- `ansible/inventory/hosts.yml` - Updated with samba

---

## Success Criteria

All criteria met ✅:

- [x] Container created and running
- [x] /mnt/storage mounted in container
- [x] Samba services active and enabled
- [x] media user configured in Samba
- [x] SMB share accessible
- [x] Configuration optimized for large files
- [x] Write permissions correct (media:media)
- [x] Password stored in secrets.yml

---

## Next Steps

1. **Encrypt secrets file** (recommended):
   ```bash
   cd /home/cuiv/dev/homelab-notes/ansible
   ansible-vault encrypt vars/secrets.yml
   echo "your_vault_password" > ~/.vault_pass
   chmod 600 ~/.vault_pass
   ```

2. **Test from your clients**:
   - Mount the share on your laptop
   - Try copying a file
   - Try streaming a movie from the library

3. **Monitor usage**:
   ```bash
   ssh root@192.168.1.56 "pct top 301"
   ```

4. **Optional enhancements**:
   - Add to monitoring system
   - Set up log rotation
   - Configure automatic updates

---

## References

- **Implementation Plan**: `docs/plans/samba-container-implementation-plan.md`
- **IaC Strategy**: `docs/reference/homelab-iac-strategy.md`
- **Backup Container**: `terraform/backup.tf` (similar pattern)

---

**Last Updated**: 2025-11-11  
**Deployment Time**: ~7 minutes (Terraform + Ansible)
