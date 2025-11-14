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

### CT301: Samba File Server
**Status**: ✅ Production  
**Purpose**: SMB file sharing for `/mnt/storage` access  
**Quick Access**: `ssh root@192.168.1.82` | `\\192.168.1.82\storage`

[📖 Full Documentation](./ct301-samba.md) | [Terraform](../../terraform/ct301-samba.tf) | [Ansible](../../ansible/playbooks/ct301-samba.yml)

---

### CT302: Ripper Container (IaC)
**Status**: ✅ Production  
**Purpose**: Blu-ray/DVD ripping with MakeMKV (IaC version)  
**Quick Access**: `ssh root@192.168.1.70`

[📖 Full Documentation](./ct302-ripper.md) | [Terraform](../../terraform/ct302-ripper.tf) | [Ansible](../../ansible/playbooks/ct302-ripper.yml)

---

### CT303: Analyzer Container (IaC)
**Status**: 🚧 Ready for Deployment  
**Purpose**: Media analysis, remuxing, and organization  
**Quick Access**: `ssh root@192.168.1.73`

[📖 Full Documentation](./ct303-analyzer.md) | [Terraform](../../terraform/ct303-analyzer.tf) | [Ansible](../../ansible/playbooks/ct303-analyzer.yml)

---

### CT101: Jellyfin Media Server  
**Status**: ✅ Production  
**Purpose**: Media streaming (movies, TV, music)  
**Quick Access**: `ssh root@192.168.1.128` | http://192.168.1.128:8096

📝 *Documentation pending*

---

### CT200: Ripper (MakeMKV) - Legacy
**Status**: ✅ Production (Manual)  
**Purpose**: Blu-ray/DVD ripping with optical drive passthrough  
**Quick Access**: `ssh root@192.168.1.75`

📝 *Documentation pending* | **Note**: Being replaced by CT302 (IaC version)

---

### CT201: Transcoder (FFmpeg)
**Status**: ✅ Production  
**Purpose**: Video transcoding with Intel Arc GPU  
**Quick Access**: `ssh root@192.168.1.77`

📝 *Documentation pending*

---

### CT202: Analyzer (Manual)
**Status**: ✅ Production  
**Purpose**: Media analysis and quality checking  
**Quick Access**: `ssh root@192.168.1.72`

📝 *Documentation pending* | **Note**: Being replaced by CT303 (IaC version)

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
- CT302 (Ripper) → CT303 (Analyzer) → CT201 (Transcoder) → CT101 (Jellyfin)
- Legacy: CT200 (Ripper - Manual), CT202 (Analyzer - Manual)

**Infrastructure:**
- CT300 (Backup)
- CT301 (Samba File Server)

**Planned:**
- Monitoring/Alerting container
- Development/Testing container

### By Management Method

**Terraform + Ansible (IaC):**
- CT300 (Backup)
- CT301 (Samba)
- CT302 (Ripper)
- CT303 (Analyzer) 🚧

**Manual (To be migrated):**
- CT101 (Jellyfin)
- CT200 (Ripper - Legacy, will be replaced by CT302)
- CT201 (Transcoder)
- CT202 (Analyzer - Legacy, will be replaced by CT303)

---

## Quick Access

### SSH to All Containers
```bash
# From jump box/local machine
ssh root@192.168.1.58   # CT300 - Backup
ssh root@192.168.1.82   # CT301 - Samba
ssh root@192.168.1.70   # CT302 - Ripper (IaC)
ssh root@192.168.1.73   # CT303 - Analyzer (IaC)
ssh root@192.168.1.128  # CT101 - Jellyfin
ssh root@192.168.1.75   # CT200 - Ripper (Legacy)
ssh root@192.168.1.77   # CT201 - Transcoder
ssh root@192.168.1.72   # CT202 - Analyzer (Legacy)

# From Proxmox host
pct enter 300   # Backup
pct enter 301   # Samba
pct enter 302   # Ripper (IaC)
pct enter 303   # Analyzer (IaC)
pct enter 101   # Jellyfin
pct enter 200   # Ripper (Legacy)
pct enter 201   # Transcoder
pct enter 202   # Analyzer (Legacy)
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
**Containers documented**: 4/8 active (CT300, CT301, CT302, CT303)  
**Next to document**: CT101 (Jellyfin), CT201 (Transcoder), CT202 (Legacy Analyzer), CT200 (Legacy Ripper)
