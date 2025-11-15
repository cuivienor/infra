#!/bin/bash
# migrate-to-1-ripped.sh - Move all existing files to 1-ripped for testing workflow
#
# Treats everything as raw rips, ignoring any partial processing

set -e

STAGING_BASE="/mnt/storage/media/staging"
DATE_STAMP=$(date +%Y-%m-%d)

echo "=========================================="
echo "Move All Files to 1-ripped"
echo "=========================================="
echo "Date: $DATE_STAMP"
echo ""
echo "This will move all files to 1-ripped/ as raw rips."
echo "You can then test the complete workflow from the beginning."
echo ""

# Show what will be migrated
echo "Files to migrate:"
echo ""
echo "MOVIES → 1-ripped/movies/:"
echo "  - Dragon → How_To_Train_Your_Dragon_${DATE_STAMP}/"
echo "  - Dragon2 → How_To_Train_Your_Dragon_2_${DATE_STAMP}/"
echo "  - LionKing → The_Lion_King_${DATE_STAMP}/"
echo "  - Matrix → The_Matrix_Disc1_${DATE_STAMP}/ (regular Blu-ray)"
echo "  - Matrix-UHD → The_Matrix_Disc2_${DATE_STAMP}/ (UHD - same movie, different quality)"
echo ""
echo "TV SHOWS → 1-ripped/tv/:"
echo "  - Cosmos → Cosmos_A_Spacetime_Odyssey/S01_Disc[1-4]_${DATE_STAMP}/"
echo "  - Avatar → Avatar_The_Last_Airbender/S01_Disc[1-2]_${DATE_STAMP}/"
echo ""
echo "Note: Dragon folder will NOT be touched (active transcode)"
echo "      All other files treated as raw rips"
echo ""
echo "=========================================="
read -p "Proceed with migration? [y/N]: " -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 0
fi

echo ""
echo "Starting migration..."
echo ""

# ============================================
# MOVIES to 1-ripped/movies/
# ============================================

echo "1. Migrating movies to 1-ripped/movies/..."

# Dragon (How To Train Your Dragon 1)
# SKIP - has active transcode happening
echo "  → Dragon → SKIPPED (active transcode in progress)"

# Dragon2 (How To Train Your Dragon 2)
echo "  → Dragon2 → How_To_Train_Your_Dragon_2_${DATE_STAMP}/"
DEST="$STAGING_BASE/1-ripped/movies/How_To_Train_Your_Dragon_2_${DATE_STAMP}"
mkdir -p "$DEST"
mv "$STAGING_BASE/Dragon2"/*.mkv "$DEST/" 2>/dev/null || true
rmdir "$STAGING_BASE/Dragon2" 2>/dev/null || true

# LionKing (The Lion King)
echo "  → LionKing → The_Lion_King_${DATE_STAMP}/"
DEST="$STAGING_BASE/1-ripped/movies/The_Lion_King_${DATE_STAMP}"
mkdir -p "$DEST"
mv "$STAGING_BASE/LionKing"/*.mkv "$DEST/" 2>/dev/null || true
rmdir "$STAGING_BASE/LionKing" 2>/dev/null || true

# Matrix (The Matrix - Disc 1, regular Blu-ray)
echo "  → Matrix → The_Matrix_Disc1_${DATE_STAMP}/"
DEST="$STAGING_BASE/1-ripped/movies/The_Matrix_Disc1_${DATE_STAMP}"
mkdir -p "$DEST"
mv "$STAGING_BASE/Matrix"/*.mkv "$DEST/" 2>/dev/null || true
rmdir "$STAGING_BASE/Matrix" 2>/dev/null || true

# Matrix-UHD (The Matrix - Disc 2, UHD)
echo "  → Matrix-UHD → The_Matrix_Disc2_${DATE_STAMP}/"
DEST="$STAGING_BASE/1-ripped/movies/The_Matrix_Disc2_${DATE_STAMP}"
mkdir -p "$DEST"
mv "$STAGING_BASE/Matrix-UHD"/*.mkv "$DEST/" 2>/dev/null || true
rmdir "$STAGING_BASE/Matrix-UHD" 2>/dev/null || true

echo ""

# ============================================
# TV SHOWS to 1-ripped/tv/
# ============================================

echo "2. Migrating TV shows to 1-ripped/tv/..."

# Cosmos (Season 1, 4 discs)
echo "  → Cosmos → Cosmos_A_Spacetime_Odyssey/"

SHOW_DIR="$STAGING_BASE/1-ripped/tv/Cosmos_A_Spacetime_Odyssey"
mkdir -p "$SHOW_DIR"

# Organize files by disc and rename to include disc identifier
for disc in 1 2 3 4; do
    DISC_DIR="$SHOW_DIR/S01_Disc${disc}_${DATE_STAMP}"
    mkdir -p "$DISC_DIR"

    echo "    → S01_Disc${disc}_${DATE_STAMP}/"

    # Move and rename files to include disc identifier
    # Pattern: "COSMOS- A SpaceTime Odyssey, Season 1 Disc X_tYY.mkv"
    find "$STAGING_BASE/Cosmos" -maxdepth 1 -name "*Disc ${disc}_t*.mkv" -print0 | while IFS= read -r -d '' file; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            # Extract track number
            if [[ "$filename" =~ _t([0-9]+)\.mkv ]]; then
                track_num="${BASH_REMATCH[1]}"
                new_name="Cosmos_A_Spacetime_Odyssey_Disc${disc}_t${track_num}.mkv"
                mv "$file" "$DISC_DIR/$new_name"
            fi
        fi
    done
done

rmdir "$STAGING_BASE/Cosmos" 2>/dev/null || true

# Avatar The Last Airbender (Season 1, 2 discs)
echo "  → Avatar → Avatar_The_Last_Airbender/"

SHOW_DIR="$STAGING_BASE/1-ripped/tv/Avatar_The_Last_Airbender"
mkdir -p "$SHOW_DIR"

# Disc 1 - rename S01E## to track format with disc identifier
echo "    → S01_Disc1_${DATE_STAMP}/ (renaming S01E## to track format)"
DISC1_DIR="$SHOW_DIR/S01_Disc1_${DATE_STAMP}"
mkdir -p "$DISC1_DIR"

# Rename S01EXX.mkv to Avatar_The_Last_Airbender_Disc1_tXX.mkv
cd "$STAGING_BASE/tv/Avatar_The_Last_Airbender/Season_1_Disc_1"
for file in S01E*.mkv; do
    if [ -f "$file" ]; then
        # Extract episode number from S01EXX.mkv
        if [[ "$file" =~ S01E([0-9]+)\.mkv ]]; then
            ep_num="${BASH_REMATCH[1]}"
            # Remove leading zero and use as track number
            track_num=$((10#$ep_num - 1))  # Episodes start at 01, tracks at 00
            track_num=$(printf "%02d" $track_num)
            new_name="Avatar_The_Last_Airbender_Disc1_t${track_num}.mkv"
            mv "$file" "$DISC1_DIR/$new_name"
        fi
    fi
done
cd - > /dev/null

# Disc 2 - has !ERRtemplate names, fix them with disc identifier
echo "    → S01_Disc2_${DATE_STAMP}/ (fixing !ERRtemplate names)"
DISC2_DIR="$SHOW_DIR/S01_Disc2_${DATE_STAMP}"
mkdir -p "$DISC2_DIR"

# Rename !ERRtemplate files to Avatar_The_Last_Airbender_Disc2_tXX.mkv
for file in "$STAGING_BASE/tv/Avatar_The_Last_Airbender/Season_1_Disc_2"/*.mkv; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        # Extract track number from !ERRtemplate_tXX.mkv
        if [[ "$filename" =~ t([0-9]+)\.mkv ]]; then
            track_num="${BASH_REMATCH[1]}"
            new_name="Avatar_The_Last_Airbender_Disc2_t${track_num}.mkv"
            mv "$file" "$DISC2_DIR/$new_name"
        fi
    fi
done

# Clean up old TV structure
rmdir "$STAGING_BASE/tv/Avatar_The_Last_Airbender/Season_1_Disc_1" 2>/dev/null || true
rmdir "$STAGING_BASE/tv/Avatar_The_Last_Airbender/Season_1_Disc_2" 2>/dev/null || true
rmdir "$STAGING_BASE/tv/Avatar_The_Last_Airbender" 2>/dev/null || true
rmdir "$STAGING_BASE/tv" 2>/dev/null || true

echo ""
echo "=========================================="
echo "✓ Migration Complete!"
echo "=========================================="
echo ""

# Show new structure
echo "New structure in 1-ripped/:"
echo ""
echo "MOVIES:"
for dir in "$STAGING_BASE/1-ripped/movies"/*; do
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "*.mkv" | wc -l)
        echo "  $(basename "$dir") - $count files"
    fi
done

echo ""
echo "TV SHOWS:"
for show_dir in "$STAGING_BASE/1-ripped/tv"/*; do
    if [ -d "$show_dir" ]; then
        echo "  $(basename "$show_dir"):"
        for disc_dir in "$show_dir"/*; do
            if [ -d "$disc_dir" ]; then
                count=$(find "$disc_dir" -name "*.mkv" | wc -l)
                echo "    $(basename "$disc_dir") - $count files"
            fi
        done
    fi
done

echo ""
echo "=========================================="
echo "Next Steps - Test Complete Workflow:"
echo "=========================================="
echo ""
echo "Pick a movie to test with (recommend Lion King - smallest):"
echo ""
echo "1. ANALYZE:"
echo "   ./analyze-media.sh /mnt/storage/media/staging/1-ripped/movies/The_Lion_King_${DATE_STAMP}/"
echo ""
echo "2. Review in Jellyfin 'Staging - Ripped' library"
echo "   - Play files to identify main feature vs extras"
echo "   - Delete any duplicates"
echo ""
echo "3. ORGANIZE & REMUX:"
echo "   ./organize-and-remux-movie.sh /mnt/storage/media/staging/1-ripped/movies/The_Lion_King_${DATE_STAMP}/"
echo ""
echo "4. Review in Jellyfin 'Staging - Remuxed' library"
echo ""
echo "5. TRANSCODE:"
echo "   ./transcode-queue.sh /mnt/storage/media/staging/2-remuxed/movies/The_Lion_King_${DATE_STAMP}/ 20 software"
echo ""
echo "6. Review in Jellyfin 'Staging - Transcoded' library"
echo ""
echo "7. PROMOTE:"
echo "   ./promote-to-ready.sh /mnt/storage/media/staging/3-transcoded/movies/The_Lion_King_${DATE_STAMP}/"
echo ""
echo "8. FILEBOT:"
echo "   ./filebot-process.sh /mnt/storage/media/staging/4-ready/movies/The_Lion_King/"
echo ""
echo "=========================================="
echo ""
echo "For TV shows, test with Avatar:"
echo ""
echo "1. ANALYZE each disc:"
echo "   ./analyze-media.sh /mnt/storage/media/staging/1-ripped/tv/Avatar_The_Last_Airbender/S01_Disc1_${DATE_STAMP}/"
echo "   ./analyze-media.sh /mnt/storage/media/staging/1-ripped/tv/Avatar_The_Last_Airbender/S01_Disc2_${DATE_STAMP}/"
echo ""
echo "2. Review in Jellyfin, delete unwanted files"
echo ""
echo "3. ORGANIZE & REMUX entire season:"
echo "   ./organize-and-remux-tv.sh \"Avatar The Last Airbender\" 01"
echo "   (Interactive: mark extras, confirm episode numbers)"
echo ""
echo "4. Continue with transcode → promote → filebot"
echo ""
