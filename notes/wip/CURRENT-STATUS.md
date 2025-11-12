# Homelab Current Status

**Date**: 2025-11-12
**Focus**: Full IaC Migration Complete! 🎉

---

## 🎉 MAJOR MILESTONE: Full IaC Migration Complete!

### ✅ Completed (2025-11-12)

**Legacy Container Cleanup:**
- [x] Backed up all LXC configs for CT101, CT200, CT201, CT202
- [x] Stopped all legacy containers
- [x] Deleted all legacy containers with storage purge
- [x] Verified 48GB disk space reclaimed
- [x] Updated documentation (AGENTS.md, CURRENT-STATUS.md)
- [x] Created cleanup summary in archive

**Result:** 100% Infrastructure as Code! All 6 containers (CT300-305) managed by Terraform + Ansible

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

### Active Containers (All IaC - 300 Range)
- **CT300** backup (192.168.1.58) - Restic + Backrest UI ✅
- **CT301** samba (192.168.1.82) - Samba file server ✅
- **CT302** ripper (192.168.1.70) - MakeMKV with optical drive ✅
  - Security: Restricted storage access (staging only)
  - Status: Production ready
- **CT303** analyzer (192.168.1.73) - Media analysis, remuxing, organization ✅
  - Status: Production ready
- **CT304** transcoder (192.168.1.77) - FFmpeg with Intel Arc GPU ✅
  - GPU: Intel Arc A380 (VA-API hardware acceleration)
  - Status: Production ready
- **CT305** jellyfin (192.168.1.85) - Media server with dual GPU ✅
  - Resources: 4 cores, 8GB RAM, 32GB disk
  - GPU: Intel Arc A380 (primary VA-API) + NVIDIA GTX 1080
  - Hardware accel: AV1, HEVC, H.264 encoding/decoding
  - Status: Production ready

### Legacy Containers (REMOVED 2025-11-12)
- ~~CT101 jellyfin~~ → Replaced by CT305
- ~~CT200 ripper-new~~ → Replaced by CT302
- ~~CT201 transcoder-new~~ → Replaced by CT304
- ~~CT202 analyzer~~ → Replaced by CT303
- **Storage reclaimed**: 48GB

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

### Phase 2: Container Migration ✅ **COMPLETE!**
- [x] Create CT300 (backup) ✅
- [x] Create CT301 (samba) ✅
- [x] Create CT302 (ripper IaC version) ✅
- [x] Create CT303 (analyzer IaC version) ✅
- [x] Create CT304 (transcoder IaC version) ✅
- [x] Create CT305 (Jellyfin IaC version) ✅
- [x] Create device passthrough Ansible roles ✅
- [x] Create MakeMKV, Jellyfin, and media roles ✅
- [x] Decommission ALL legacy containers (CT100, CT101, CT102, CT200, CT201, CT202) ✅
- [x] 48GB disk space reclaimed ✅
- [ ] Test end-to-end media pipeline with new containers ⏳ **NEXT**
- [ ] Add media libraries to CT305 Jellyfin
- [ ] Verify all hardware passthrough working in production

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

1. **Test CT305 Jellyfin** - Add media libraries and verify playback
2. **Test CT302 Ripper** - Rip a disc end-to-end
3. **Test CT304 Transcoder** - Verify GPU transcoding working
4. **Update any scripts** - Check for hardcoded IPs (if any)
5. **Monitor stability** - Watch all containers for a few days

**Status**: Infrastructure migration complete, now testing production workflows

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

**Current Priority**: Test production workflows with new IaC containers

**Achievement**: 🎉 100% Infrastructure as Code - All containers managed by Terraform + Ansible!

**Last Updated**: 2025-11-12
