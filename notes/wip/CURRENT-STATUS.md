# Homelab Current Status

**Date**: 2025-11-11
**Focus**: IaC Implementation + Backup System

---

## 🎯 Current Work: Backup System with IaC

### ✅ Completed (2025-11-11)

**Infrastructure as Code Setup:**
- [x] Created Terraform configuration for CT300 (backup container)
- [x] Created Ansible role `restic_backup` for automated backups
- [x] Designed hybrid approach: custom scripts + Backrest UI
- [x] Simplified backup policy to "data" (all /mnt/storage except media)
- [x] Complete documentation for deployment

**Files Created:**
- `terraform/main.tf` - Terraform provider config
- `terraform/variables.tf` - Variable definitions
- `terraform/containers/ct300-backup.tf` - Backup container definition
- `terraform/terraform.tfvars.example` - Example secrets
- `terraform/README.md` - Terraform usage guide
- `ansible/roles/restic_backup/` - Complete backup role
- `ansible/playbooks/ct300-backup.yml` - Container playbook
- `ansible/vars/backup_secrets.yml.example` - B2/restic secrets template
- `docs/guides/ct300-backup-deployment.md` - Deployment walkthrough
- `docs/guides/backup-setup.md` - Detailed backup guide
- `docs/reference/backup-quick-reference.md` - Command reference
- `docs/plans/backup-implementation-summary.md` - Complete overview

### 🎯 Next Steps

**Deploy CT300 Backup Container:**

1. **Get Backblaze B2 credentials**
   - Sign up at backblaze.com
   - Create app key
   - Create bucket: `homelab-data`
   - Generate restic password

2. **Configure secrets**
   ```bash
   cd ~/dev/homelab-notes
   
   # Terraform secrets
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   nano terraform/terraform.tfvars  # Add Proxmox password
   
   # Ansible secrets
   cp ansible/vars/backup_secrets.yml.example ansible/vars/backup_secrets.yml
   nano ansible/vars/backup_secrets.yml  # Add B2 credentials
   ansible-vault encrypt ansible/vars/backup_secrets.yml
   ```

3. **Deploy with Terraform**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

4. **Configure with Ansible**
   ```bash
   export CT300_IP="<ip-from-terraform>"
   ansible-playbook ansible/playbooks/ct300-backup.yml --vault-password-file ~/.vault_pass
   ```

5. **Test backup**
   ```bash
   ssh homelab "pct exec 300 -- systemctl start restic-backup-data.service"
   ssh homelab "pct exec 300 -- /etc/restic/scripts/maintenance.sh snapshots data"
   ```

**See**: `docs/guides/ct300-backup-deployment.md` for complete walkthrough

---

## 📁 Current Infrastructure

### Proxmox Host (homelab - 192.168.1.56)
- **Hardware**: i5-9600K, 32GB RAM, 35TB MergerFS pool
- **Storage**: `/mnt/storage` (4.1TB used, 29TB free)
- **GPU**: Intel Arc A380 (transcoding), NVIDIA GTX 1080
- **Optical**: /dev/sr0 (Blu-ray)

### Active Containers (Manual)
- **CT101** jellyfin (192.168.1.128) - Media server
- **CT200** ripper-new (192.168.1.75) - MakeMKV, optical drive
- **CT201** transcoder-new (192.168.1.77) - FFmpeg, Intel Arc GPU
- **CT202** analyzer (192.168.1.72) - Media analysis

### IaC Containers (300 Range)
- **CT300** backup (deployed) - Restic + Backrest UI ✅
- **CT301** samba (deployed) - Samba file server ✅
- **CT302** ripper (deployed 2025-11-11) - MakeMKV with optical drive ✅
  - IP: 192.168.1.70
  - Security: Restricted storage access (staging only)
  - Status: Production ready, CT200 remains as backup

---

## 💾 Backup Strategy

### Current State: Ready for Deployment

**Backup Policy: `data`**
- **What**: Everything in `/mnt/storage` except large media
- **Included**: photos, documents, backups, e-books, audiobooks
- **Excluded**: Movies, TV, media pipeline directories
- **Target**: Backblaze B2 (`homelab-data` bucket)
- **Schedule**: Daily at 2 AM
- **Retention**: 7 daily, 4 weekly, 6 monthly, 2 yearly
- **Encryption**: Restic (client-side)

**3-2-1 Backup Strategy:**
1. ✅ Live data on MergerFS (35TB with SnapRAID parity)
2. ⏳ Restic → Backblaze B2 (encrypted cloud) **← Deploying now**
3. ⏳ Future: Local/family member backup

**Estimated Cost**: $0.50-$2.50/month depending on data size

---

## 🎬 Media Pipeline Status

### Current: v2 Implementation Complete

**Directory Structure:**
```
/mnt/storage/media/staging/
├── 1-ripped/          ← Migrated files here
│   ├── movies/
│   └── tv/
├── 2-remuxed/         ← Ready for use
├── 3-transcoded/      ← Ready for use
└── 4-ready/           ← Ready for use
```

**Scripts Ready:**
- `rip-disc.sh` - MakeMKV automation
- `analyze-media.sh` - Media analysis
- `organize-and-remux-movie.sh` - Movie processing
- `organize-and-remux-tv.sh` - TV processing
- `transcode-queue.sh` - Transcoding
- `promote-to-ready.sh` - Stage promotion
- `filebot-process.sh` - FileBot automation

**Status**: Ready for testing (pending backup deployment)

---

## 📊 IaC Progress

### Phase 1: Foundation (In Progress)
- [x] Repository organized for IaC
- [x] Comprehensive documentation (current-state.md)
- [x] Terraform setup (main.tf, variables.tf)
- [x] First container definition (CT300)
- [x] Ansible role created (restic_backup)
- [ ] Deploy first IaC container ⏳ **NEXT**
- [ ] Test Terraform + Ansible workflow
- [ ] Document lessons learned

### Phase 2: Container Migration (In Progress)
- [x] Create CT302 (ripper IaC version) ✅
- [x] Create device passthrough Ansible role ✅
- [x] Create MakeMKV Ansible role ✅
- [x] Decommission legacy containers (CT100, CT102) ✅
- [x] Deploy and test CT302 ✅ **DEPLOYED 2025-11-11**
  - Security enhancement: Restricted storage mount (staging only)
  - All verification tests passed
  - MakeMKV v1.18.2 compiled and configured
- [ ] Test CT302 with actual disc ripping ⏳ **NEXT**
- [ ] Plan cutover from CT200 to CT302
- [ ] Import CT201 (transcoder) to Terraform
- [ ] Import CT202 (analyzer) to Terraform

### Phase 3: Host Configuration (Planned)
- [ ] Ansible role for MergerFS configuration
- [ ] Ansible role for SnapRAID configuration
- [ ] Host backup (Proxmox configs, LXC configs)
- [ ] Disaster recovery testing

---

## 🔑 Secrets Management

**Terraform Secrets** (git-ignored):
- `terraform/terraform.tfvars` - Proxmox credentials

**Ansible Secrets** (vault-encrypted):
- `ansible/vars/backup_secrets.yml` - B2 + restic passwords

**Vault Password**:
- Stored in `~/.vault_pass` (chmod 600)
- Used with `--vault-password-file ~/.vault_pass`

---

## 📚 Documentation Structure

```
docs/
├── guides/               # Step-by-step how-to
│   ├── backup-setup.md
│   ├── ct300-backup-deployment.md
│   ├── jellyfin-setup.md
│   └── media-pipeline-v2.md
├── reference/            # Quick reference
│   ├── backup-quick-reference.md
│   ├── current-state.md
│   └── media-pipeline-quick-reference.md
├── plans/                # Planning docs
│   ├── backup-implementation-summary.md
│   └── storage-iac-plan.md
└── archive/              # Completed work
```

---

## 🎯 Immediate Action Items

1. **Get B2 credentials** (backblaze.com)
2. **Configure secrets** (terraform.tfvars, backup_secrets.yml)
3. **Deploy CT300** (terraform apply)
4. **Run Ansible** (configure backups)
5. **Test backup** (first manual run)
6. **Monitor** (verify daily automation)

**Time estimate**: 1-2 hours for complete setup

---

## 🐛 Known Issues

**Backup System:**
- None - ready for deployment

**Media Pipeline:**
- [ ] Duplicate filenames in TV shows (fix-current-names.sh)
- [ ] Dragon folder still in old structure

**Infrastructure:**
- [ ] CT300-302 range not yet defined in AGENTS.md
- [ ] Backup role not yet listed in AGENTS.md

---

## 📖 Key Reference Files

**For Deployment:**
- `docs/guides/ct300-backup-deployment.md` - Start here
- `terraform/README.md` - Terraform usage
- `ansible/roles/restic_backup/README.md` - Role documentation

**For Reference:**
- `docs/reference/backup-quick-reference.md` - Daily commands
- `docs/reference/current-state.md` - Full system inventory
- `AGENTS.md` - AI context and conventions

---

## 🚀 Success Criteria

CT300 deployment is successful when:
- [x] Terraform creates container
- [ ] Container gets DHCP IP
- [ ] Storage mounted at /mnt/storage
- [ ] Ansible completes without errors
- [ ] First backup finishes
- [ ] Snapshot visible in B2
- [ ] Test restore succeeds
- [ ] Daily timer is active

---

**Current Priority**: Deploy CT300 backup container (first IaC container!)

**Next After That**: Test media pipeline with backup in place

**Last Updated**: 2025-11-11
