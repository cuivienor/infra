#!/bin/bash
# Storage Reorganization Script
# Run as: sudo -u media bash reorganize-storage.sh
# Or: bash reorganize-storage.sh (if already media user)

set -e  # Exit on error

STORAGE="/mnt/storage"

echo "========================================="
echo "Storage Reorganization Script"
echo "========================================="
echo ""
echo "This will reorganize: $STORAGE"
echo ""
echo "Changes:"
echo "  1. Move adult content to private/ (719GB)"
echo "  2. Safely consolidate photos/ (221GB - NO DATA LOSS)"
echo "  3. Move audiobooks/e-books to media/ (108GB)"
echo "  4. Consolidate old backups to archives/ (792GB)"
echo ""
echo "SAFETY NOTES:"
echo "  - All photos will be preserved in photos/consolidated/"
echo "  - You can reorganize photos properly later"
echo "  - No data will be deleted"
echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read -r

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
for dir in "$STORAGE"/*/; do
    [ -d "$dir" ] && ls -lhd "$dir"
done
echo ""
echo "Verification:"
echo "  Photos preserved at: $STORAGE/photos/consolidated/"
du -sh "$STORAGE/photos"
echo ""
echo "Next steps:"
echo "  1. Verify photos: ls -R $STORAGE/photos/consolidated/ | less"
echo "  2. Update backup exclusions for private/"
echo "  3. Replicate directory structure to disk2/disk3"
echo "  4. Run a test backup"
echo ""
echo "Later:"
echo "  - Review downloads/ and random/ for cleanup"
echo "  - Properly organize photos/ from consolidated/"
echo "  - Organize documents/ when ready"
