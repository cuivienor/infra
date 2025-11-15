# Quick Start: Homelab IaC Implementation

Fast reference for implementing Infrastructure as Code.

---

## Current Status

✅ **Repository**: Organized and documented  
✅ **System**: Fully inspected and documented  
✅ **Storage Plan**: Complete and ready to implement  
⏳ **Container IaC**: Documentation ready, code TBD

---

## Priority 1: Storage Automation

**Status**: Ready to implement  
**Risk**: Low  
**Time**: 1-2 hours  
**Plan**: `docs/plans/storage-iac-plan.md`

### Quick Fix (Restore SnapRAID Now)

```bash
# 1. Install SnapRAID
ssh homelab << 'EOF'
cd /tmp
wget https://github.com/amadvance/snapraid/releases/download/v12.3/snapraid-12.3.tar.gz
tar xzf snapraid-12.3.tar.gz
cd snapraid-12.3
./configure && make && sudo make install
EOF

# 2. Create config
ssh homelab "sudo tee /etc/snapraid.conf > /dev/null << 'SEOF'
# SnapRAID configuration
parity /mnt/parity/snapraid.parity

content /mnt/disk1/.snapraid.content
content /mnt/disk2/.snapraid.content
content /mnt/disk3/.snapraid.content

data d1 /mnt/disk1
data d2 /mnt/disk2
data d3 /mnt/disk3

exclude *.unrecoverable
exclude /tmp/
exclude /lost+found/
exclude *.DS_Store
exclude /.Trashes

block_size 256
hash blake2
autosave 500
SEOF
"

# 3. Test it
ssh homelab "snapraid status"

# 4. Set up daily sync
ssh homelab "sudo crontab -l | { cat; echo '0 3 * * * /usr/local/bin/snapraid sync'; } | sudo crontab -"
```

### Full IaC (Complete Automation)

See complete code in: `docs/plans/storage-iac-plan.md`

```bash
# 1. Create Ansible role structure
mkdir -p ansible/roles/proxmox_storage/{defaults,tasks,templates,files,handlers}

# 2. Copy code from plan to appropriate files
# - defaults/main.yml (variables)
# - tasks/*.yml (implementation)
# - templates/*.j2 (config templates)
# - files/snapraid-runner.sh (automation script)

# 3. Create playbook
cat > ansible/playbooks/storage.yml << 'EOF'
---
- name: Configure Proxmox storage
  hosts: proxmox_hosts
  become: yes
  roles:
    - proxmox_storage
EOF

# 4. Test
ansible-playbook ansible/playbooks/storage.yml --check

# 5. Apply
ansible-playbook ansible/playbooks/storage.yml
```

---

## Priority 2: Container IaC

**Status**: Planning phase  
**Next**: Create test container  
**Plan**: `docs/reference/homelab-iac-strategy.md`

### Phase 1: Test Container (CTID 199)

```bash
# 1. Create Terraform provider
cat > terraform/providers.tf << 'EOF'
terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.50"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure = true
  ssh {
    agent = true
  }
}
EOF

# 2. Create test container definition
cat > terraform/containers/test.tf << 'EOF'
resource "proxmox_virtual_environment_container" "test" {
  description = "Test container for IaC workflow"
  node_name   = "homelab"
  vm_id       = 199

  started     = true

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  mount_point {
    path   = "/mnt/storage"
    volume = "/mnt/storage"
  }

  initialization {
    hostname = "test-iac"
    dns {
      domain  = "local"
      servers = ["8.8.8.8"]
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  features {
    nesting = true
  }
}
EOF

# 3. Initialize and test
cd terraform
terraform init
terraform plan
terraform apply
```

---

## Essential Commands

### Storage Management

```bash
# Check MergerFS status
ssh homelab "df -h /mnt/storage && mount | grep mergerfs"

# Check SnapRAID status (after installing)
ssh homelab "snapraid status"

# Run manual sync
ssh homelab "snapraid sync"

# Run scrub (8% of array)
ssh homelab "snapraid scrub -p 8"
```

### Container Management

```bash
# List containers
ssh homelab "pct list"

# Enter container
ssh homelab "pct enter <CTID>"

# Check GPU
ssh homelab "pct exec 201 -- vainfo --display drm --device /dev/dri/renderD128"

# Check optical drive
ssh homelab "pct exec 200 -- ls -la /dev/sr0 /dev/sg4"
```

### Terraform Workflow

```bash
cd terraform

# Initialize
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Import existing
terraform import proxmox_virtual_environment_container.name homelab/lxc/<CTID>
```

### Ansible Workflow

```bash
cd ansible

# Test connectivity
ansible homelab -m ping

# Run playbook (dry run)
ansible-playbook playbooks/storage.yml --check

# Run playbook
ansible-playbook playbooks/storage.yml

# Run with tags
ansible-playbook playbooks/storage.yml --tags snapraid
```

---

## Documentation Reference

| Document | Purpose |
|----------|---------|
| `AGENTS.md` | Complete context for AI assistants |
| `QUICK-REFERENCE.md` | One-page command cheat sheet |
| `docs/reference/current-state.md` | Complete system inventory |
| `docs/reference/homelab-iac-strategy.md` | Full IaC implementation plan |
| `docs/plans/storage-iac-plan.md` | Storage automation (ready!) |
| `notes/wip/SYSTEM-SNAPSHOT.md` | Current running state |

---

## Implementation Checklist

### Storage Automation
- [ ] Install SnapRAID binary
- [ ] Create `/etc/snapraid.conf`
- [ ] Test `snapraid status`
- [ ] Set up automated sync (cron or systemd)
- [ ] Set up automated scrub (weekly)
- [ ] Test manual sync
- [ ] Verify logs are working

### Container IaC (Phase 1)
- [ ] Create Terraform provider config
- [ ] Create test container definition
- [ ] Run `terraform plan`
- [ ] Apply and verify container created
- [ ] Create Ansible inventory
- [ ] Create common role
- [ ] Test Ansible playbook
- [ ] Test destroy/recreate workflow

### Container IaC (Phase 2)
- [ ] Import CT200 (ripper-new)
- [ ] Import CT201 (transcoder-new)
- [ ] Import CT202 (analyzer)
- [ ] Create device passthrough roles
- [ ] Create application roles (MakeMKV, FFmpeg)
- [ ] Test full deployment
- [ ] Document any issues

---

## Next Steps

**This Week**:
1. ✅ Choose: Quick fix or full IaC for storage
2. ✅ Implement chosen approach
3. ✅ Test and verify

**Next Week**:
1. Start Terraform test container
2. Create Ansible roles
3. Test workflow

**This Month**:
1. Import production containers
2. Automate device passthrough
3. Complete disaster recovery test

---

**Last Updated**: 2025-11-11  
**Ready to Implement**: Storage automation  
**In Progress**: Container IaC planning
