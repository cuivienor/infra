# Storage Reorganization - Quick Summary

**Date**: 2025-11-11  
**Status**: Ready to execute

---

## What's Changing

### Current Structure (Messy)
```
/mnt/storage/
├── Porn/              # 330GB - adult content
├── New folder/        # 389GB - adult content  
├── Photos/            # 204GB - old photos (2010-2014)
├── photos/            # 17GB - recent photos (UUID)
├── audiobooks/        # 50GB - at root
├── e-books/           # 58GB - at root
├── Movies/            # 493GB - old library
├── tv/                # 13GB - old library
├── backups/           # 8KB - scattered backups
├── backup-bbg/        # 5.9GB
├── ani-backup/        # 841MB
└── [many others]
```

### New Structure (Clean)
```
/mnt/storage/
├── media/             # ALL media content (1.9TB)
│   ├── staging/       # (existing - rip pipeline)
│   ├── movies/        # (existing - organized)
│   ├── tv/            # (existing - organized)
│   ├── audiobooks/    # ← MOVED from root
│   └── e-books/       # ← MOVED from root
├── photos/            # ALL photos safely consolidated (221GB)
│   └── consolidated/
│       ├── Photos-archive/       # (old Photos/ 2010-2014)
│       └── recent-uuid-backup/   # (old photos/ UUID)
├── documents/         # Placeholder for future organization
├── archives/          # Old backups + legacy media
│   ├── backups/
│   │   ├── immich/
│   │   ├── bbg/
│   │   └── mobile/
│   └── legacy-media/  # (old Movies/ and tv/)
├── private/           # Adult content (EXCLUDED FROM BACKUP)
├── downloads/         # (keep as-is for now)
├── random/            # (keep as-is for now)
└── temp/
```

---

## Quick Execution

### 1. Run the Script

```bash
# SSH to Proxmox host
ssh homelab

# Run as media user
sudo -u media bash ~/dev/homelab-notes/scripts/utils/reorganize-storage.sh

# Or copy to host first
scp ~/dev/homelab-notes/scripts/utils/reorganize-storage.sh homelab:/tmp/
ssh homelab "sudo -u media bash /tmp/reorganize-storage.sh"
```

**Time**: 20 minutes + 1-2 hours for moves

### 2. Verify Photos

```bash
# Check all photos are there
ls -R /mnt/storage/photos/consolidated/
du -sh /mnt/storage/photos/
```

Should show 221GB total.

### 3. Update Backup Exclusions

Already done in: `ansible/roles/restic_backup/defaults/main.yml`

Excludes:
- ✅ `/mnt/storage/media/**` (ALL media)
- ✅ `/mnt/storage/private/**` (adult content)
- ✅ `/mnt/storage/archives/legacy-media/**` (old Movies/TV)

### 4. Replicate to Other Disks

```bash
ssh homelab
cd /mnt/disk1
find . -type d -not -path '*/lost+found*' -not -path '*/\.*' -print0 | \
  xargs -0 -I {} mkdir -p /mnt/disk2/{} /mnt/disk3/{}
```

---

## Key Benefits

### Privacy ✅
- Adult content in `private/` - **NOT backed up**
- Saves ~$3.60/month on B2 storage

### Safety ✅
- **NO photos deleted** - all preserved in `photos/consolidated/`
- Can reorganize properly later

### Organization ✅
- All media in one place (`media/`)
- Photos consolidated (ready for future organization)
- Old backups in `archives/`

### Cost Savings ✅

| What | Before | After | Savings |
|------|--------|-------|---------|
| Backup size | 4.1TB | 860GB | 3.2TB |
| B2 cost/month | $20.50 | $4.30 | $16.20 |
| **Annual savings** | - | - | **$194** |

---

## What Gets Backed Up

### ✅ Backed Up (860GB)
- `photos/` - ALL photos (221GB) 🔒
- `archives/backups/` - Important backups (6.7GB)
- `documents/` - Future documents
- `downloads/` - 629GB (review later)
- `random/` - 157GB (review later)

### ❌ Excluded (3.2TB)
- `media/` - ALL media (movies, tv, audiobooks, e-books, staging)
- `private/` - Adult content
- `archives/legacy-media/` - Old Movies/TV
- `temp/` - Temporary files

---

## After Reorganization

### Immediate
1. ✅ Verify photos intact
2. ✅ Re-run Ansible to apply new exclusions
3. ✅ Test backup with new structure
4. ✅ Monitor first few backups

### Later (Your Time)
- Review `downloads/` for cleanup (save more $$$)
- Review `random/` for cleanup
- Properly organize `photos/consolidated/`
- Organize `documents/` directory

---

## Safety Notes

- ✅ Script won't delete anything
- ✅ All photos preserved (both Photos/ and photos/)
- ✅ Can undo by moving directories back
- ✅ MergerFS moves are fast (metadata only on most disks)

---

## Full Documentation

- **Complete plan**: `docs/plans/storage-reorganization-plan.md`
- **Script location**: `scripts/utils/reorganize-storage.sh`

---

**Ready to run?** Just execute the script and verify photos afterward!
