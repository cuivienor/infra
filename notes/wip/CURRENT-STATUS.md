# Current Work Status

**Date**: 2025-11-15  
**Focus**: DNS Infrastructure Deployment

> **📖 For system specifications**, see `docs/reference/current-state.md`

---

## 🎉 Recent Achievement

**2025-11-15**: DNS Infrastructure Deployed!
- ✅ AdGuard Home on Pi4 (primary DNS at 192.168.1.102)
- ✅ AdGuard Home on CT310 (backup DNS at 192.168.1.110)
- ✅ 12 local DNS rewrites for paniland.com services
- ✅ Full IaC via Ansible role and playbook
- ✅ Credentials secured in Ansible Vault

**2025-11-12**: Full IaC Migration Complete!
- ✅ All 6 containers (CT300-305) managed by Terraform + Ansible
- ✅ All legacy containers (CT101, CT200-202) removed
- ✅ 48GB disk space reclaimed
- ✅ 100% Infrastructure as Code

---

## 🎯 Current Priorities

### 1. Test Production Workflows ⏳

**Need to verify**:
- [ ] jellyfin - Add media libraries and test playback
- [ ] ripper - Rip a test disc end-to-end
- [ ] transcoder - Verify GPU transcoding working
- [ ] analyzer - Test FileBot organization
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

**Active Containers**: 7 (all IaC-managed)

| CTID | Name | Status | Notes |
|------|------|--------|-------|
| 300 | backup | ✅ Running | Restic + Backrest |
| 301 | samba | ✅ Running | File shares |
| 302 | ripper | ✅ Running | Optical drive passthrough configured |
| 303 | analyzer | ✅ Running | FileBot ready |
| 304 | transcoder | ✅ Running | Intel Arc GPU passthrough configured |
| 305 | jellyfin | ✅ Running | Dual GPU passthrough configured |
| 310 | dns | ✅ Running | Backup DNS (AdGuard Home) |

**DNS Infrastructure**:
- Primary: Pi4 (192.168.1.102) - AdGuard Home
- Backup: CT310 (192.168.1.110) - AdGuard Home

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
1. ✅ ~~Deploy DNS infrastructure~~ DONE
2. Test DNS from local machine: `dig @192.168.1.102 jellyfin.paniland.com`
3. Configure one client to use new DNS servers
4. Update UniFi DHCP to distribute new DNS servers
5. Test Jellyfin with existing media libraries

### Short Term (This Month)
1. Complete media library migration to new structure
2. Run full backup test (restic + restore)
3. Consider adding Unbound for recursive DNS
4. Explore Tailscale for remote access (Phase 2 of networking plan)
5. Update any scripts with hardcoded IPs/paths

### Medium Term (Next 3 Months)
1. Add reverse proxy (Caddy) for HTTPS
2. Configure Tailscale subnet routing
3. Test disaster recovery workflow
4. Add monitoring solution
5. Consider CI/CD for IaC changes

---

## 🔧 Recent Changes

### 2025-11-15 (Evening)
- ✅ Deployed AdGuard Home on Pi4 as primary DNS (192.168.1.102)
- ✅ Created CT310 backup DNS container via Terraform
- ✅ Deployed AdGuard Home on CT310 (192.168.1.110)
- ✅ Created Ansible role `adguard_home` with full IaC config
- ✅ Configured 12 local DNS rewrites for paniland.com services
- ✅ Secured admin credentials in Ansible Vault
- ✅ Updated networking plan with correct IPs and decisions
- ✅ Fixed container IPs in current-state.md (now match Terraform)

### 2025-11-15 (Morning)
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
- `docs/guides/ripping-workflow-movie.md` - Movie ripping workflow
- `docs/guides/ripping-workflow-tv.md` - TV show ripping workflow
- `docs/guides/backup-setup.md` - Backup configuration

**Planning**:
- `docs/plans/storage-iac-plan.md` - Storage IaC strategy
- `docs/plans/network-iac-implementation-plan.md` - Network IaC plan

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
