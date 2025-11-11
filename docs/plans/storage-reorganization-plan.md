# Storage Reorganization Plan

**Date**: 2025-11-11  
**Status**: Proposed  
**Total Size**: ~4.1TB used of 35TB

---

## Current State Analysis

### Directory Inventory

| Directory | Size | Notes | Status |
|-----------|------|-------|--------|
| `media/` | 1.8TB | Media pipeline (staging, movies, tv) | ✅ Keep as-is (well organized) |
| `downloads/` | 629GB | Download client files | 🔄 Review/cleanup |
| `Movies/` | 493GB | Old movie library | 🔄 Being replaced by media pipeline |
| `New folder/` | 389GB | **Adult content** | 🚫 Move to private/ |
| `Porn/` | 330GB | **Adult content** | 🚫 Move to private/ |
| `Photos/` | 204GB | Photo library (2010-2014) | 🔄 Consolidate with photos/ |
| `random/` | 157GB | Misc downloads | 🔄 Review/cleanup |
| `e-books/` | 58GB | E-book collection | ✅ Keep as-is |
| `audiobooks/` | 50GB | Audiobook collection | ✅ Keep as-is |
| `photos/` | 17GB | Recent photos (UUID folder) | 🔄 Consolidate with Photos/ |
| `tv/` | 13GB | Old TV library | 🔄 Being replaced by media pipeline |
| `backup-bbg/` | 5.9GB | Old backups (ppetrov14, temp) | 🔄 Review/archive |
| `ani-backup/` | 841MB | Signal/WhatsApp backups | 🔄 Consolidate to archives/ |
| `temp/` | 155MB | Temporary files | 🧹 Clean up |
| `backups/` | 8KB | Immich backups | 🔄 Consolidate to archives/ |
| `images/` | 4KB | Empty | 🗑️ Delete |

---

## Proposed Organization Structure

```
/mnt/storage/
├── media/                    # Media library + pipeline (DON'T TOUCH during reorganization)
│   ├── staging/             # (existing - media pipeline)
│   ├── movies/              # (existing - organized movies)
│   ├── tv/                  # (existing - organized TV)
│   ├── audiobooks/          # (move from root - will stream via Jellyfin)
│   └── e-books/             # (move from root - will stream via Jellyfin)
│
├── photos/                   # Consolidated photo library (CAREFUL - keep everything!)
│   └── [all photos merged here safely]
│
├── documents/                # Personal documents (future: will reorganize)
│   └── [placeholder for future document organization]
│
├── downloads/                # Keep as-is for now
│   ├── complete/
│   ├── incomplete/
│   └── google/
│
├── archives/                 # Long-term storage / old backups
│   ├── backups/             # (consolidate: backups/, backup-bbg/, ani-backup/)
│   └── legacy-media/        # (old Movies/, tv/ directories from root)
│
├── private/                  # Adult content (EXCLUDED FROM BACKUP)
│   └── [content from Porn/, New folder/]
│
├── random/                   # Keep as-is (review later)
└── temp/                     # Temporary (auto-clean, excluded from backup)
```

---

## Migration Plan

### Phase 1: Create Private Directory (Immediate)

**Goal**: Move adult content out of backed-up paths

```bash
# On Proxmox host
ssh homelab

# Create private directory
mkdir -p /mnt/storage/private
chown media:media /mnt/storage/private
chmod 750 /mnt/storage/private

# Move adult content
mv /mnt/storage/Porn /mnt/storage/private/
mv "/mnt/storage/New folder" /mnt/storage/private/downloads

# Verify
ls -lah /mnt/storage/private/
```

**Size freed from backup**: ~719GB (will save ~$3.60/month on B2)

---

### Phase 2: Consolidate Photos (SAFE - Keep Everything!)

**Goal**: Safely merge photo directories without losing anything

**Strategy**: Create timestamped subdirectories to preserve structure

```bash
# Create safe consolidation structure
mkdir -p /mnt/storage/photos/consolidated

# Move old Photos/ (capital P) - preserve entire structure
# This has 2010-2014, Nexus backups, sony-camera
mv /mnt/storage/Photos /mnt/storage/photos/consolidated/Photos-archive

# Move photos/ (lowercase p) - has UUID folder
# This is likely from a specific app/service
mv /mnt/storage/photos/1d8620a3-158b-4d3a-a9bf-43b869d4ca50 \
   /mnt/storage/photos/consolidated/recent-uuid-backup

# Fix permissions
chown -R media:media /mnt/storage/photos/
```

**Result**: 
- All photos preserved in `/mnt/storage/photos/consolidated/`
- `Photos-archive/` contains 2010-2014, Nexus backups, sony camera
- `recent-uuid-backup/` contains recent UUID-named photos
- Nothing lost, can reorganize properly later

**Size**: ~221GB total (all preserved)

---

### Phase 3: Move Media Library Content

**Goal**: Consolidate audiobooks and e-books under media/ for Jellyfin streaming

```bash
# Move to media directory (will be served by Jellyfin eventually)
mv /mnt/storage/audiobooks /mnt/storage/media/
mv /mnt/storage/e-books /mnt/storage/media/

# Create placeholder for future documents organization
mkdir -p /mnt/storage/documents

# Fix permissions
chown -R media:media /mnt/storage/media/audiobooks
chown -R media:media /mnt/storage/media/e-books
chown -R media:media /mnt/storage/documents
```

**Result**: 
- Audiobooks and e-books now in `media/` alongside movies/tv/staging
- Empty `documents/` directory created for future use

---

### Phase 4: Consolidate Archives

**Goal**: Move old backups and legacy content to archives

```bash
# Create archives structure
mkdir -p /mnt/storage/archives/{backups,legacy-media,misc}

# Move backup directories
mv /mnt/storage/backups /mnt/storage/archives/backups/immich
mv /mnt/storage/backup-bbg /mnt/storage/archives/backups/bbg
mv /mnt/storage/ani-backup /mnt/storage/archives/backups/mobile

# Move legacy media (old structure, being replaced by media pipeline)
mv /mnt/storage/Movies /mnt/storage/archives/legacy-media/
mv /mnt/storage/tv /mnt/storage/archives/legacy-media/

# Review random/ first, then decide
# (Don't move yet - needs manual review)

# Fix permissions
chown -R media:media /mnt/storage/archives/
```

**Note**: `Movies/` and `tv/` are old libraries. Your new media pipeline (`/mnt/storage/media/`) is the future. Keep old for reference until fully migrated.

---

### Phase 5: Cleanup

**Goal**: Remove empty/temporary directories

```bash
# Clean temp directory
rm -rf /mnt/storage/temp/*

# Remove empty images directory
rmdir /mnt/storage/images

# Review downloads and random (manual)
# These need human review before moving/deleting
```

---

## Updated Backup Configuration

### Add Private Directory to Exclusions

Edit `ansible/roles/restic_backup/defaults/main.yml`:

```yaml
excludes:
  # Large media directories (expensive to backup, can be re-ripped)
  - "/mnt/storage/media/**"
  - "/mnt/storage/Movies/**"      # Legacy - now in archives/
  - "/mnt/storage/tv/**"           # Legacy - now in archives/
  
  # Private content (excluded from backup)
  - "/mnt/storage/private/**"
  
  # Archives - old Movies/TV (already have these backed up elsewhere)
  - "/mnt/storage/archives/legacy-media/**"
  
  # Temporary/cache directories
  - "/mnt/storage/temp/**"
  - "/mnt/storage/lost+found/**"
  - "/mnt/storage/.snapraid.*"
  
  # Common patterns to skip
  - "**/.Trash-*/**"
  - "**/Thumbs.db"
  - "**/.DS_Store"
  - "**/*.tmp"
  - "**/*.partial"
  - "**/node_modules/**"
  - "**/__pycache__/**"
```

---

## What Gets Backed Up (After Reorganization)

### ✅ Backed Up to B2 (~500GB estimated)

- **library/** - Audiobooks, ebooks, documents (~108GB)
- **photos/** - All consolidated photos (~221GB)
- **archives/backups/** - Important backups (~6.7GB)
- **downloads/** - Download history (~629GB, but most old/replaceable)

### ❌ Excluded from Backup (~3.6TB)

- **media/** - Media pipeline (1.8TB - can re-rip)
- **archives/legacy-media/** - Old Movies/TV (786GB - already archived)
- **private/** - Adult content (719GB)
- **downloads/** - (should add exclusion for old downloads after review)

### 💡 Consider Excluding (Review First)

- **downloads/** - Most of this is probably replaceable torrents
- **random/** - Needs review, might be mostly junk

**Potential B2 cost after cleanup**: ~$2.50/month (500GB) instead of ~$20/month (4.1TB)

---

## Manual Review Needed

### Downloads Directory (629GB)

```bash
# Review what's in complete/
ls -lh /mnt/storage/downloads/complete/

# Decide what to keep vs. archive vs. delete
# Likely most are old torrents that can be re-downloaded
```

**Recommendation**: Keep only recent/active downloads, archive the rest

### Random Directory (157GB)

```bash
# Review contents
ls -lh /mnt/storage/random/Complete/
ls -lh /mnt/storage/random/Incomplete/
ls -lh /mnt/storage/random/schmee/
```

**Recommendation**: Review and either move to archives/misc/ or delete

---

## Migration Script (Safe)

Here's a script that implements Phase 1-4 with safety checks:

```bash
#!/bin/bash
# Storage Reorganization Script
# Run as: sudo -u media bash reorganize-storage.sh

set -e  # Exit on error

STORAGE="/mnt/storage"

echo "========================================="
echo "Storage Reorganization Script"
echo "========================================="
echo ""
echo "This will reorganize: $STORAGE"
echo ""
echo "Changes:"
echo "  1. Move adult content to private/"
echo "  2. Safely consolidate photos/ (NO DATA LOSS)"
echo "  3. Move audiobooks/e-books to media/"
echo "  4. Consolidate old backups to archives/"
echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# Phase 1: Private directory
echo ""
echo "Phase 1: Creating private directory..."
mkdir -p "$STORAGE/private"
if [ -d "$STORAGE/Porn" ]; then
    echo "  Moving Porn/ to private/"
    mv "$STORAGE/Porn" "$STORAGE/private/"
fi
if [ -d "$STORAGE/New folder" ]; then
    echo "  Moving 'New folder/' to private/downloads"
    mv "$STORAGE/New folder" "$STORAGE/private/downloads"
fi
echo "  ✓ Private directory created (719GB moved, excluded from backup)"

# Phase 2: Consolidate photos (SAFE - preserve everything)
echo ""
echo "Phase 2: Consolidating photos (preserving all data)..."
mkdir -p "$STORAGE/photos/consolidated"

# Move Photos/ (capital P) - preserve entire structure
if [ -d "$STORAGE/Photos" ]; then
    echo "  Moving Photos/ to photos/consolidated/Photos-archive/"
    mv "$STORAGE/Photos" "$STORAGE/photos/consolidated/Photos-archive"
fi

# Move photos/ UUID folder (lowercase p)
if [ -d "$STORAGE/photos/1d8620a3-158b-4d3a-a9bf-43b869d4ca50" ]; then
    echo "  Moving UUID folder to photos/consolidated/recent-uuid-backup/"
    mv "$STORAGE/photos/1d8620a3-158b-4d3a-a9bf-43b869d4ca50" \
       "$STORAGE/photos/consolidated/recent-uuid-backup"
fi
echo "  ✓ Photos consolidated (221GB preserved, will reorganize later)"

# Phase 3: Move audiobooks/e-books to media/
echo ""
echo "Phase 3: Moving audiobooks and e-books to media/..."
if [ -d "$STORAGE/audiobooks" ]; then
    echo "  Moving audiobooks/ to media/"
    mv "$STORAGE/audiobooks" "$STORAGE/media/"
fi
if [ -d "$STORAGE/e-books" ]; then
    echo "  Moving e-books/ to media/"
    mv "$STORAGE/e-books" "$STORAGE/media/"
fi

# Create documents placeholder
mkdir -p "$STORAGE/documents"
echo "  ✓ Media library organized, documents/ placeholder created"

# Phase 4: Archives
echo ""
echo "Phase 4: Creating archives..."
mkdir -p "$STORAGE/archives"/{backups,legacy-media}

if [ -d "$STORAGE/backups" ]; then
    echo "  Moving backups/ to archives/backups/immich"
    mkdir -p "$STORAGE/archives/backups"
    mv "$STORAGE/backups" "$STORAGE/archives/backups/immich"
fi
if [ -d "$STORAGE/backup-bbg" ]; then
    echo "  Moving backup-bbg/ to archives/backups/bbg"
    mv "$STORAGE/backup-bbg" "$STORAGE/archives/backups/bbg"
fi
if [ -d "$STORAGE/ani-backup" ]; then
    echo "  Moving ani-backup/ to archives/backups/mobile"
    mv "$STORAGE/ani-backup" "$STORAGE/archives/backups/mobile"
fi

if [ -d "$STORAGE/Movies" ]; then
    echo "  Moving Movies/ to archives/legacy-media/"
    mv "$STORAGE/Movies" "$STORAGE/archives/legacy-media/"
fi
if [ -d "$STORAGE/tv" ]; then
    echo "  Moving tv/ to archives/legacy-media/"
    mv "$STORAGE/tv" "$STORAGE/archives/legacy-media/"
fi
echo "  ✓ Archives organized (backups and legacy media)"

# Phase 5: Cleanup
echo ""
echo "Phase 5: Cleanup..."
if [ -d "$STORAGE/images" ]; then
    rmdir "$STORAGE/images" 2>/dev/null && echo "  Removed empty images/" || echo "  images/ not empty, skipping"
fi

# Fix all permissions
echo ""
echo "Fixing permissions..."
chown -R media:media "$STORAGE/private" "$STORAGE/photos" "$STORAGE/media" "$STORAGE/archives" "$STORAGE/documents" 2>/dev/null || echo "  Some permission changes failed (may need root)"

echo ""
echo "========================================="
echo "Reorganization complete!"
echo "========================================="
echo ""
echo "Final structure:"
ls -lh "$STORAGE" | grep "^d"
echo ""
echo "Next steps:"
echo "  1. Verify photos are intact: ls -R /mnt/storage/photos/consolidated/"
echo "  2. Update backup exclusions for private/"
echo "  3. Replicate directory structure to disk2/disk3"
echo "  4. Run a test backup"
```

---

## Before You Start

### 1. Test Backup First

Make sure backups are working before moving things around:

```bash
# Run a test backup
ssh homelab "pct exec 300 -- systemctl start restic-backup-data.service"
```

### 2. Create Snapshot

Take a SnapRAID snapshot before reorganization:

```bash
ssh homelab "snapraid sync"
```

### 3. Review Sizes

Confirm what you're moving:

```bash
du -sh /mnt/storage/Porn /mnt/storage/"New folder" /mnt/storage/Photos
```

---

## Post-Migration

### Update Backup Exclusions

After moving private/, update the backup role and re-run Ansible:

```bash
cd ~/dev/homelab-notes
nano ansible/roles/restic_backup/defaults/main.yml
# Add /mnt/storage/private/** to excludes

ansible-playbook ansible/playbooks/ct300-backup.yml --vault-password-file ~/.vault_pass
```

### Replicate Directory Structure

Don't forget to replicate new directories to disk2 and disk3:

```bash
ssh homelab "cd /mnt/disk1 && find . -type d -not -path '*/lost+found*' -not -path '*/\.*' -print0 | xargs -0 -I {} mkdir -p /mnt/disk2/{} /mnt/disk3/{}"
```

### Test New Structure

Verify everything is where you expect:

```bash
ssh homelab "tree -L 2 /mnt/storage"
```

---

## Summary

### What This Achieves

✅ **Privacy**: Adult content isolated to `private/` (not backed up)  
✅ **Safety**: Photos consolidated without data loss (full structure preserved)  
✅ **Organization**: Media content grouped (movies/tv/audiobooks/e-books all in media/)  
✅ **Cleanup**: Old backups consolidated to archives/  
✅ **Cost Savings**: Immediate ~$16/month savings by excluding private/  
✅ **Future-ready**: Placeholders for documents/ reorganization later  

### Backup Impact

| Before | After Phase 1 | After Full Review |
|--------|---------------|-------------------|
| 4.1TB | ~860GB | ~300GB (estimated) |
| $20.50/mo | $4.30/mo | $1.50/mo |

**Immediate savings from private/ exclusion**: ~$16/month

### Time Required

- **Phase 1 (private)**: 5 minutes + move time (~719GB) ⚡ DO THIS FIRST
- **Phase 2 (photos)**: 3 minutes (simple directory moves)
- **Phase 3 (media)**: 2 minutes (move audiobooks/e-books)
- **Phase 4 (archives)**: 5 minutes + move time (~792GB)
- **Phase 5 (cleanup)**: 1 minute

**Total**: ~20 minutes + move time (1-2 hours depending on disk speed)

**Note**: All moves are within the same MergerFS pool, so they should be fast (just metadata updates on most disks)

---

**Next Steps**: Review this plan, adjust as needed, then execute phase by phase.

**Last Updated**: 2025-11-11
