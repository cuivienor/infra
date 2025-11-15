# Raspberry Pi Setup Guide

**Created:** 2025-11-15  
**Purpose:** Migrate existing Pis + standardize for future setups

---

## Two Approaches

### 1. Current Migration (One-Time)
**For:** Your existing Pis that need cleanup and upgrade  
**Method:** Bash script (`scripts/utils/migrate-raspberry-pis.sh`)  
**What it does:** SSH keys, cleanup old software, upgrade OS, remove old users

### 2. Fresh Pi Setup (Repeatable)
**For:** Any fresh Raspberry Pi going forward  
**Method:** Ansible playbook (`ansible/playbooks/raspberry-pi-setup.yml`)  
**What it does:** Standard configuration, packages, hardening

---

## Current Migration (Do This Now)

### What You Have

| Pi | IP | User | OS | Status |
|----|-----|------|-----|--------|
| pihole | 192.168.1.107 | pi | Debian 11 | Needs migration |
| raspberrypi | 192.168.1.114 | cuiv | Debian 11 | Needs migration |

### What You Want

| Pi | IP | User | OS | Status |
|----|-----|------|-----|--------|
| pihole | 192.168.1.107 | cuiv | Debian 12 | Clean, managed |
| raspberrypi | 192.168.1.114 | cuiv | Debian 12 | Clean, managed |

### Run the Migration Script

**One command does everything:**

```bash
cd ~/dev/homelab-notes
./scripts/utils/migrate-raspberry-pis.sh
```

**What it does:**

1. **Deploy SSH Keys**
   - Creates `cuiv` user on both Pis
   - Deploys your SSH public key
   - Sets up passwordless sudo

2. **Cleanup Old Software**
   - Removes Pi-hole completely
   - Removes Docker and containers
   - Cleans up old configs
   - Removes old service files

3. **Upgrade OS**
   - Upgrades to Debian 12 (Bookworm)
   - Updates all packages
   - Reboots each Pi

4. **Final Cleanup**
   - Installs essential packages
   - Removes old users (`pi`, `media`)
   - Disables WiFi/Bluetooth

5. **Verification**
   - Confirms Debian 12
   - Confirms cuiv user
   - Confirms old software removed

**Time:** ~1 hour total (mostly automated, prompts at each phase)

### After Migration

```bash
# Test Ansible connectivity
cd ~/dev/homelab-notes/ansible
ansible raspberry_pis -m ping

# Expected:
# pihole | SUCCESS => { "ping": "pong" }
# raspberrypi | SUCCESS => { "ping": "pong" }
```

**Your Pis are now:**
- ✅ Debian 12 (Bookworm)
- ✅ User: cuiv (SSH key access only)
- ✅ Clean system (no old software)
- ✅ Managed by Ansible

---

## Ansible Playbook (Use for Future Setups)

### When to Use

- Setting up a **brand new** Raspberry Pi
- After a **fresh OS installation**
- **Re-running** to ensure consistent config

### Prerequisites

1. Fresh Raspberry Pi OS installed
2. User `cuiv` exists
3. SSH key deployed to `cuiv`
4. Pi accessible on network

### Run the Playbook

```bash
cd ~/dev/homelab-notes/ansible

# Configure both Pis
ansible-playbook playbooks/raspberry-pi-setup.yml

# Or just one
ansible-playbook playbooks/raspberry-pi-setup.yml --limit pihole
```

### What It Configures

✅ **System updates** - Full apt upgrade  
✅ **Essential packages** - vim, git, curl, htop, tmux, etc.  
✅ **User setup** - Ensures cuiv with passwordless sudo  
✅ **SSH hardening** - Key-only auth, no root login  
✅ **WiFi disabled** - Ethernet only  
✅ **Hostname** - Sets proper hostname  
✅ **Timezone** - Configures timezone  

### Idempotent

Safe to run multiple times - won't break anything!

```bash
# Run anytime to ensure Pi is in correct state
ansible-playbook playbooks/raspberry-pi-setup.yml
```

---

## Inventory Configuration

After migration, your inventory uses SSH keys:

**`ansible/inventory/hosts.yml`:**
```yaml
raspberry_pis:
  hosts:
    pihole:
      ansible_host: 192.168.1.107
      ansible_user: cuiv  # ← Standard user
      # No passwords! Uses SSH key

    raspberrypi:
      ansible_host: 192.168.1.114
      ansible_user: cuiv  # ← Standard user
      # No passwords! Uses SSH key
```

---

## Quick Reference

### Test Connectivity
```bash
ansible raspberry_pis -m ping
```

### Check OS Version
```bash
ansible raspberry_pis -m shell -a "cat /etc/os-release | grep PRETTY_NAME"
```

### Check Current User
```bash
ansible raspberry_pis -m shell -a "whoami"
```

### Run Updates
```bash
ansible raspberry_pis -m apt -a "update_cache=yes upgrade=full" -b
```

### Run Setup Playbook
```bash
ansible-playbook playbooks/raspberry-pi-setup.yml
```

### Test Playbook
```bash
ansible-playbook playbooks/raspberry-pi-test.yml
```

---

## Troubleshooting

### SSH Key Not Working

**Test manually:**
```bash
ssh cuiv@192.168.1.107  # Should work without password
```

**Fix:**
```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub cuiv@192.168.1.107
```

### Pi Not Responding After Migration

**Check:**
```bash
ping 192.168.1.107
```

**Wait:** Give it 5 minutes after reboot

**Power cycle:** Physically unplug and replug if needed

### Ansible Connection Failed

**Check inventory:**
```bash
cat ansible/inventory/hosts.yml | grep -A5 raspberry_pis
```

**Test SSH directly:**
```bash
ssh cuiv@192.168.1.107
ssh cuiv@192.168.1.114
```

---

## Files Created

```
scripts/utils/
└── migrate-raspberry-pis.sh     # ← One-time migration script

ansible/playbooks/
├── raspberry-pi-setup.yml       # ← Repeatable setup playbook (NEW)
└── raspberry-pi-test.yml        # ← Test connectivity

ansible/inventory/
└── hosts.yml                    # ← Updated: cuiv user, SSH keys
```

---

## Next Steps

After migration:

1. **Verify Pis are clean:**
   ```bash
   ansible-playbook playbooks/raspberry-pi-test.yml
   ```

2. **Keep them updated:**
   ```bash
   # Add to cron or run manually
   ansible raspberry_pis -m apt -a "update_cache=yes upgrade=full" -b
   ```

3. **Deploy services** (when ready):
   - Create roles for AdGuard Home, Tailscale, etc.
   - Use Ansible to manage services

4. **Future Pi setup:**
   - Flash fresh OS
   - Create cuiv user
   - Deploy SSH key
   - Run `ansible-playbook raspberry-pi-setup.yml`

---

## Summary

**Migration (now):**
```bash
./scripts/utils/migrate-raspberry-pis.sh
```

**Setup (future):**
```bash
ansible-playbook playbooks/raspberry-pi-setup.yml
```

**Test:**
```bash
ansible raspberry_pis -m ping
```

That's it! Simple, clean, repeatable.
