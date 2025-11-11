# Container Documentation

Operational documentation for all homelab LXC containers.

---

## Active Containers

### CT300: Backup Container
**Status**: ✅ Production  
**Purpose**: Automated backups to Backblaze B2  
**Quick Access**: `ssh root@192.168.1.58`

[📖 Full Documentation](./ct300-backup.md) | [Terraform](../../terraform/ct300-backup.tf) | [Ansible](../../ansible/playbooks/ct300-backup.yml)

---

### CT101: Jellyfin Media Server  
**Status**: ✅ Production  
**Purpose**: Media streaming (movies, TV, music)  
**Quick Access**: `ssh root@192.168.1.128` | http://192.168.1.128:8096

📝 *Documentation pending*

---

### CT200: Ripper (MakeMKV)
**Status**: ✅ Production  
**Purpose**: Blu-ray/DVD ripping with optical drive passthrough  
**Quick Access**: `ssh root@192.168.1.75`

📝 *Documentation pending*

---

### CT201: Transcoder (FFmpeg)
**Status**: ✅ Production  
**Purpose**: Video transcoding with Intel Arc GPU  
**Quick Access**: `ssh root@192.168.1.77`

📝 *Documentation pending*

---

### CT202: Analyzer
**Status**: ✅ Production  
**Purpose**: Media analysis and quality checking  
**Quick Access**: `ssh root@192.168.1.72`

📝 *Documentation pending*

---

## Deprecated Containers

### CT100: Ripper (Old)
**Status**: ⚠️ Deprecated  
**Purpose**: Replaced by CT200  
**Action**: Can be destroyed

### CT102: Transcoder (Old)
**Status**: ⚠️ Deprecated  
**Purpose**: Replaced by CT201  
**Action**: Can be destroyed

---

## Container Overview

### By Purpose

**Media Pipeline:**
- CT200 (Ripper) → CT201 (Transcoder) → CT202 (Analyzer) → CT101 (Jellyfin)

**Infrastructure:**
- CT300 (Backup)

**Planned:**
- Monitoring/Alerting container
- Development/Testing container

### By Management Method

**Terraform + Ansible (IaC):**
- CT300 (Backup)

**Manual (To be migrated):**
- CT101 (Jellyfin)
- CT200 (Ripper)
- CT201 (Transcoder)
- CT202 (Analyzer)

---

## Quick Access

### SSH to All Containers
```bash
# From jump box/local machine
ssh root@192.168.1.58   # CT300 - Backup
ssh root@192.168.1.128  # CT101 - Jellyfin
ssh root@192.168.1.75   # CT200 - Ripper
ssh root@192.168.1.77   # CT201 - Transcoder
ssh root@192.168.1.72   # CT202 - Analyzer

# From Proxmox host
pct enter 300   # Backup
pct enter 101   # Jellyfin
pct enter 200   # Ripper
pct enter 201   # Transcoder
pct enter 202   # Analyzer
```

### Container Status from Proxmox
```bash
ssh root@192.168.1.56 "pct list"
```

---

## Creating New Container Documentation

When creating documentation for a new container:

1. **Copy the template:**
   ```bash
   cp docs/containers/_template.md docs/containers/ctXXX-name.md
   ```

2. **Fill in all sections:**
   - Update CTID, hostname, IP, purpose
   - Document access methods
   - Add common operations
   - Document troubleshooting steps
   - List future plans

3. **Add to this index:**
   - Add entry in appropriate section
   - Link to documentation file
   - Update quick access section

4. **Link from related docs:**
   - Add to relevant guides
   - Update quick reference docs
   - Link from IaC files (Terraform/Ansible)

---

## Documentation Standards

### What to Include

**Must have:**
- Container purpose and overview
- Access methods (SSH, web UI)
- Common operations
- Troubleshooting guide
- Configuration locations

**Should have:**
- Scheduled tasks
- Monitoring/health checks
- Update procedures
- Related documentation links

**Nice to have:**
- Performance notes
- Lessons learned
- Cost information
- Future plans

### What NOT to Include

**Avoid:**
- Sensitive credentials (use "See vault" or "See password manager")
- Excessive implementation details (those go in guides)
- Redundant information from guides
- Outdated information (keep it current!)

### Tone & Style

- **User-facing**: Written for operators, not developers
- **Action-oriented**: Focus on "how to" not "how it works"
- **Concise**: Quick reference, not comprehensive manual
- **Maintained**: Keep updated as things change

---

## Related Documentation

- [Homelab IaC Strategy](../reference/homelab-iac-strategy.md)
- [Container Deployment Guides](../guides/)
- [Quick Start IaC](../reference/quick-start-iac.md)
- [Current State](../reference/current-state.md)

---

**Last updated**: 2025-11-11  
**Containers documented**: 1/5 active  
**Next to document**: CT101 (Jellyfin), CT200 (Ripper), CT201 (Transcoder), CT202 (Analyzer)
