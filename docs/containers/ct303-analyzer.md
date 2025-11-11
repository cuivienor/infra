# CT303: Analyzer Container

**Status**: IaC Managed (300 series)  
**Purpose**: Media analysis, remuxing, and organization  
**Replaces**: CT202 (manual container)

---

## Quick Info

| Property | Value |
|----------|-------|
| **CTID** | 303 |
| **Hostname** | analyzer |
| **IP** | 192.168.1.73 (static) |
| **Type** | Privileged LXC |
| **Resources** | 2 cores, 4GB RAM, 12GB disk |
| **Storage** | `/mnt/staging` → `/mnt/storage/media/staging` |
| **Tags** | `media`, `iac`, `analyzer` |

---

## Purpose

The analyzer container handles all media analysis and organization tasks in the pipeline:

1. **Analysis** - Inspect media files (duration, size, tracks)
2. **Duplicate Detection** - Find potential duplicate files
3. **Remuxing** - Remove unwanted audio/subtitle tracks
4. **Organization** - Prepare files for transcoding and library
5. **Pipeline Promotion** - Move files between stages

---

## Installed Tools

- **mkvtoolnix** (mkvmerge) - MKV manipulation
- **mediainfo** - Media file analysis
- **jq** - JSON processing
- **bc** - Calculations
- **rsync** - File operations

---

## Scripts

Located in `/home/media/scripts/`:

| Script | Purpose |
|--------|---------|
| `analyze-media.sh` | Analyze MKV files in directory |
| `organize-and-remux-movie.sh` | Process movies (1-ripped → 2-remuxed) |
| `organize-and-remux-tv.sh` | Process TV shows (1-ripped → 2-remuxed) |
| `promote-to-ready.sh` | Move files (3-transcoded → 4-ready) |
| `filebot-process.sh` | FileBot automation (4-ready → library) |
| `fix-current-names.sh` | Fix naming issues |

---

## Quick Commands

### Access Container
```bash
pct enter 303
su - media
```

### Analyze Media
```bash
~/scripts/analyze-media.sh /mnt/staging/1-ripped/movies/Movie_Name/
```

### Process Movie
```bash
~/scripts/organize-and-remux-movie.sh /mnt/staging/1-ripped/movies/Movie_2024-11-10/
```

### Process TV Show
```bash
~/scripts/organize-and-remux-tv.sh "Show Name" 01
```

### Promote to Ready
```bash
~/scripts/promote-to-ready.sh /mnt/staging/3-transcoded/movies/Movie_Name/
```

---

## IaC Management

### Terraform
```bash
# Deploy/update container
cd terraform
terraform apply -target=proxmox_virtual_environment_container.analyzer

# Show current state
terraform show | grep -A 30 "analyzer"

# Destroy (careful!)
terraform destroy -target=proxmox_virtual_environment_container.analyzer
```

### Ansible
```bash
# Full configuration
cd ansible
ansible-playbook playbooks/ct303-analyzer.yml

# Specific tags
ansible-playbook playbooks/ct303-analyzer.yml --tags analyzer
ansible-playbook playbooks/ct303-analyzer.yml --tags verify

# Test connectivity
ansible ct303 -m ping
```

---

## Media Pipeline Role

### Position in Pipeline

```
CT302 (Ripper)     CT303 (Analyzer)     CT201 (Transcoder)     CT303 (Analyzer)
     ↓                    ↓                      ↓                      ↓
0-raw (discs)  →  1-ripped (MKV)  →  2-remuxed (filtered)  →  3-transcoded  →  4-ready
                       ↓                                                            ↓
                   ANALYZE                                                    PROMOTE
                   ORGANIZE                                                      ↓
                   REMUX                                                    FileBot (optional)
                                                                                  ↓
                                                                            library/movies
                                                                            library/tv
```

### What Analyzer Does

**Stage 1-2: Analyze & Remux**
- Analyzes ripped files from CT302
- Detects duplicates
- Categorizes main features vs extras
- Remuxes to remove non-English/Bulgarian tracks
- Outputs to `2-remuxed/` for transcoding

**Stage 3-4: Promote**
- After CT201 transcodes to `3-transcoded/`
- Promotes files to `4-ready/`
- Prepares for library import

**Stage 4-Library: FileBot** (optional)
- Automated organization
- Moves to final library structure

---

## Security Model

**Least Privilege Design:**
- Only mounts `/mnt/storage/media/staging/` (not full storage)
- Cannot access personal files, backups, etc.
- Follows security pattern from CT302

**Access Scope:**
```
CT303 CAN access:
  /mnt/staging/1-ripped/
  /mnt/staging/2-remuxed/
  /mnt/staging/3-transcoded/
  /mnt/staging/4-ready/

CT303 CANNOT access:
  /mnt/storage/photos/
  /mnt/storage/backups/
  /mnt/storage/media/movies/  (final library)
  /mnt/storage/media/tv/      (final library)
```

---

## Troubleshooting

### Scripts Not Working
```bash
# Check scripts exist
ls -la /home/media/scripts/

# Fix permissions
chown -R media:media /home/media/scripts/
chmod +x /home/media/scripts/*.sh

# Re-deploy with Ansible
ansible-playbook playbooks/ct303-analyzer.yml --tags analyzer
```

### Tools Missing
```bash
# Check installed
mkvmerge --version
mediainfo --version

# Reinstall with Ansible
ansible-playbook playbooks/ct303-analyzer.yml --tags analyzer
```

### Storage Mount Issues
```bash
# Check mount
ls -la /mnt/staging/

# Verify from host
ssh root@192.168.1.56 "pct exec 303 -- ls -la /mnt/staging/"

# Check LXC config
ssh root@192.168.1.56 "grep mp0 /etc/pve/lxc/303.conf"
```

---

## Related Resources

- **Deployment Guide**: `docs/guides/ct303-analyzer-deployment.md`
- **Terraform Config**: `terraform/ct303-analyzer.tf`
- **Ansible Playbook**: `ansible/playbooks/ct303-analyzer.yml`
- **Ansible Role**: `ansible/roles/media_analyzer/`
- **Media Pipeline**: `docs/reference/media-pipeline-quick-reference.md`

---

**Last Updated**: 2025-11-11  
**Status**: Ready for deployment
