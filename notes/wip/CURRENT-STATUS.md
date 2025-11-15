# Current Work Status

**Date**: 2025-11-15  
**Focus**: Container DNS Configuration & Base Setup

> **📖 For system specifications**, see `docs/reference/current-state.md`

---

## 🎉 Recent Achievement

**2025-11-12**: Full IaC Migration Complete!
- ✅ All 6 containers (CT300-305) managed by Terraform + Ansible
- ✅ All legacy containers (CT101, CT200-202) removed
- ✅ 48GB disk space reclaimed
- ✅ 100% Infrastructure as Code

---

## 🎯 Current Priorities

### 1. Test Production Workflows ⏳

**Need to verify**:
- [ ] CT305 (Jellyfin) - Add media libraries and test playback
- [ ] CT302 (Ripper) - Rip a test disc end-to-end
- [ ] CT304 (Transcoder) - Verify GPU transcoding working
- [ ] CT303 (Analyzer) - Test FileBot organization
- [ ] End-to-end pipeline: Rip → Transcode → Organize → Serve

**Status**: Infrastructure ready, workflows not yet tested

---

### 2. Documentation Cleanup ✅

- [x] Consolidated current-state.md (updated Nov 14)
- [x] Archived SYSTEM-SNAPSHOT.md
- [x] Streamlined CURRENT-STATUS.md (this file)
- [x] Updated AGENTS.md to concise format

---

## 📊 Infrastructure Status

**Active Containers**: 6 (all IaC-managed)

| CTID | Name | Status | Notes |
|------|------|--------|-------|
| 300 | backup | ✅ Running | Restic + Backrest |
| 301 | samba | ✅ Running | File shares |
| 302 | ripper | ✅ Running | Optical drive passthrough configured |
| 303 | analyzer | ✅ Running | FileBot ready |
| 304 | transcoder | ✅ Running | Intel Arc GPU passthrough configured |
| 305 | jellyfin | ✅ Running | Dual GPU passthrough configured |

**Storage**: 4.6TB / 35TB used (14%)

---

## 🐛 Known Issues

### High Priority
- None currently blocking

### Medium Priority
- [ ] Duplicate filenames in TV shows (need to run fix-current-names.sh)
- [ ] Legacy library migration to new `/media/library` structure incomplete

### Low Priority
- [ ] Some old docs may reference legacy container numbers (CT200 vs CT302)
- [ ] Some containers have systemd-hostnamed timeouts (normal for LXC)

---

## 📋 Next Steps

### Immediate (This Week)
1. Test Jellyfin with existing media libraries
2. Rip one test disc through full pipeline
3. Verify GPU transcoding performance
4. Document any issues discovered

### Short Term (This Month)
1. Complete media library migration to new structure
2. Run full backup test (restic + restore)
3. Create deployment automation script
4. Update any scripts with hardcoded IPs/paths

### Medium Term (Next 3 Months)
1. Automate host configuration with Ansible
2. Test disaster recovery workflow
3. Add monitoring solution
4. Consider CI/CD for IaC changes

---

## 🔧 Recent Changes

### 2025-11-15
- ✅ Fixed container DNS configuration (containers had no nameservers)
- ✅ Added DNS servers (1.1.1.1, 8.8.8.8) to all Terraform container configs
- ✅ Applied base Ansible configuration to all containers (locale, timezone, packages)
- ✅ Installed common packages (sudo, vim, curl, htop, tmux) on all containers
- ✅ Fixed SSH config to use new Proxmox IP (.100)
- ✅ Fixed hostname issue in Ansible inventory (ct301_samba → ct301-samba)

### 2025-11-14
- ✅ Updated `current-state.md` with accurate CT300-305 container info
- ✅ Archived `SYSTEM-SNAPSHOT.md` to `docs/archive/`
- ✅ Streamlined `CURRENT-STATUS.md` (removed redundant static info)
- ✅ Updated `AGENTS.md` to concise ~30 line format

### 2025-11-12
- ✅ Removed all legacy containers (CT101, CT200-202)
- ✅ Verified all IaC containers production-ready
- ✅ Reclaimed 48GB disk space

### 2025-11-11
- ✅ Deployed all CT300-305 containers via Terraform
- ✅ Configured all Ansible roles and playbooks
- ✅ Set up device passthrough for GPU and optical drive
- ✅ Created comprehensive IaC documentation

---

## 🔑 Quick Commands

### Daily Operations

```bash
# Check all containers
ssh root@homelab "pct list"

# Check storage usage
ssh root@homelab "df -h /mnt/storage"

# Enter a container
ssh root@homelab "pct enter <CTID>"
```

### Testing

```bash
# Test GPU in transcoder
ssh root@homelab "pct exec 304 -- vainfo --display drm --device /dev/dri/renderD128"

# Test optical drive in ripper
ssh root@homelab "pct exec 302 -- makemkvcon info disc:0"

# Check Jellyfin GPU
ssh root@homelab "pct exec 305 -- vainfo --display drm --device /dev/dri/renderD128"
```

### IaC Operations

```bash
# Apply Terraform changes
cd ~/dev/homelab-notes/terraform
terraform plan
terraform apply

# Run Ansible playbook
cd ~/dev/homelab-notes
ansible-playbook ansible/playbooks/site.yml --vault-password-file .vault_pass

# Dry-run with tags
ansible-playbook ansible/playbooks/site.yml --tags jellyfin --check
```

---

## 📚 Key Documentation

**Reference** (static info):
- `docs/reference/current-state.md` - Full system specifications
- `docs/reference/backup-quick-reference.md` - Backup commands
- `docs/reference/media-pipeline-quick-reference.md` - Pipeline commands
- `AGENTS.md` - AI agent context and conventions

**Guides** (how-to):
- `docs/guides/jellyfin-setup.md` - Jellyfin configuration
- `docs/guides/ct302-ripper-deployment.md` - Ripper setup
- `docs/guides/backup-setup.md` - Backup configuration
- `docs/guides/media-pipeline-v2.md` - Pipeline workflow

**Planning**:
- `docs/plans/storage-iac-plan.md` - Storage IaC strategy
- `docs/reference/homelab-iac-strategy.md` - Overall IaC approach

---

## 💡 Notes

### Lessons Learned
- Privileged containers simplified GPU/optical drive passthrough significantly
- Terraform + Ansible combination works well (Terraform provisions, Ansible configures)
- Static IPs in Terraform avoid DHCP issues during deployment
- Restricted storage mounts (staging-only) improve security for ripper/transcoder

### Future Improvements
- Consider read-only mounts for Jellyfin library access
- Add monitoring container (Grafana/Prometheus)
- Implement automated testing for Ansible playbooks
- Create snapshot backup before major changes

---

**Status**: 🚀 Ready for production testing  
**Last Updated**: 2025-11-15
