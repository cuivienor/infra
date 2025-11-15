#!/bin/bash
# migrate-staging.sh - Migrate existing files to new structure
#
# This script organizes your existing staging files into the new 4-stage structure

set -e

STAGING_BASE="/mnt/storage/media/staging"
DATE_STAMP=$(date +%Y-%m-%d)

echo "=========================================="
echo "Staging Directory Migration"
echo "=========================================="
echo "Date: $DATE_STAMP"
echo ""
echo "This will migrate your existing files to the new structure."
echo "Files will be MOVED (not copied) to save space."
echo ""

# Show what will be migrated
echo "Files to migrate:"
echo ""
echo "MOVIES (raw rips → 1-ripped):"
echo "  - Dragon2 (How To Train Your Dragon 2) - 17 files"
echo "  - LionKing (The Lion King) - 6 files (including final.mkv)"
echo "  - Matrix (The Matrix) - 6 files"
echo "  - Matrix-UHD (The Matrix 4K) - 4 files"
echo ""
echo "MOVIES (partially processed):"
echo "  - Dragon (How To Train Your Dragon) - has transcoded files"
echo "    Action: Move originals to 2-remuxed, transcoded to 3-transcoded"
echo ""
echo "TV SHOWS (raw rips → 1-ripped):"
echo "  - Cosmos (Season 1, 4 discs) - 27 files"
echo ""
echo "TV SHOWS (partially processed):"
echo "  - Avatar S01 Disc 1 - already renamed (S01E01-S01E19)"
echo "  - Avatar S01 Disc 2 - needs fixing (!ERRtemplate names)"
echo "    Action: Move both to 1-ripped with proper naming"
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
# MOVIES - Raw Rips to 1-ripped
# ============================================

echo "1. Migrating movies (raw rips) to 1-ripped/movies/..."

# Dragon2 (How To Train Your Dragon 2)
echo "  → Dragon2 → How_To_Train_Your_Dragon_2_${DATE_STAMP}"
mkdir -p "$STAGING_BASE/1-ripped/movies/How_To_Train_Your_Dragon_2_${DATE_STAMP}"
mv "$STAGING_BASE/Dragon2"/*.mkv "$STAGING_BASE/1-ripped/movies/How_To_Train_Your_Dragon_2_${DATE_STAMP}/"
rmdir "$STAGING_BASE/Dragon2"

# LionKing (The Lion King)
echo "  → LionKing → The_Lion_King_${DATE_STAMP}"
mkdir -p "$STAGING_BASE/1-ripped/movies/The_Lion_King_${DATE_STAMP}"
mv "$STAGING_BASE/LionKing"/*.mkv "$STAGING_BASE/1-ripped/movies/The_Lion_King_${DATE_STAMP}/"
rmdir "$STAGING_BASE/LionKing"

# Matrix (The Matrix - regular Blu-ray)
echo "  → Matrix → The_Matrix_${DATE_STAMP}"
mkdir -p "$STAGING_BASE/1-ripped/movies/The_Matrix_${DATE_STAMP}"
mv "$STAGING_BASE/Matrix"/*.mkv "$STAGING_BASE/1-ripped/movies/The_Matrix_${DATE_STAMP}/"
rmdir "$STAGING_BASE/Matrix"

# Matrix-UHD (The Matrix - 4K UHD)
echo "  → Matrix-UHD → The_Matrix_UHD_${DATE_STAMP}"
mkdir -p "$STAGING_BASE/1-ripped/movies/The_Matrix_UHD_${DATE_STAMP}"
mv "$STAGING_BASE/Matrix-UHD"/*.mkv "$STAGING_BASE/1-ripped/movies/The_Matrix_UHD_${DATE_STAMP}/"
rmdir "$STAGING_BASE/Matrix-UHD"

echo ""

# ============================================
# MOVIES - Partially Processed (Dragon)
# ============================================

echo "2. Migrating Dragon (partially transcoded)..."

# Dragon has both originals and transcoded versions
# Originals (remuxed, track-filtered) → 2-remuxed
# Transcoded versions → 3-transcoded

DRAGON_REMUXED="$STAGING_BASE/2-remuxed/movies/How_To_Train_Your_Dragon_${DATE_STAMP}"
DRAGON_TRANSCODED="$STAGING_BASE/3-transcoded/movies/How_To_Train_Your_Dragon_${DATE_STAMP}"

mkdir -p "$DRAGON_REMUXED"
mkdir -p "$DRAGON_REMUXED/extras"
mkdir -p "$DRAGON_TRANSCODED"
mkdir -p "$DRAGON_TRANSCODED/extras"

# Move originals to 2-remuxed
echo "  → Originals to 2-remuxed"
mv "$STAGING_BASE/Dragon/How To Train Your Dragon.mkv" "$DRAGON_REMUXED/"
mv "$STAGING_BASE/Dragon/How To Train Your Dragon - Extra 1.mkv" "$DRAGON_REMUXED/extras/"
mv "$STAGING_BASE/Dragon/How To Train Your Dragon - Extra 2.mkv" "$DRAGON_REMUXED/extras/"

# Move transcoded to 3-transcoded
echo "  → Transcoded to 3-transcoded"
mv "$STAGING_BASE/Dragon/How To Train Your Dragon_transcoded.mkv" "$DRAGON_TRANSCODED/How To Train Your Dragon.mkv"
mv "$STAGING_BASE/Dragon/How To Train Your Dragon - Extra 1_transcoded.mkv" "$DRAGON_TRANSCODED/extras/How To Train Your Dragon - Extra 1.mkv"
mv "$STAGING_BASE/Dragon/How To Train Your Dragon - Extra 2_transcoded.mkv" "$DRAGON_TRANSCODED/extras/How To Train Your Dragon - Extra 2.mkv"

rmdir "$STAGING_BASE/Dragon"

echo ""

# ============================================
# TV SHOWS - Raw Rips to 1-ripped
# ============================================

echo "3. Migrating TV shows (raw rips) to 1-ripped/tv/..."

# Cosmos (Season 1, 4 discs)
echo "  → Cosmos"

# Create show directory
mkdir -p "$STAGING_BASE/1-ripped/tv/Cosmos_A_Spacetime_Odyssey"

# Organize by disc
for disc in 1 2 3 4; do
    DISC_DIR="$STAGING_BASE/1-ripped/tv/Cosmos_A_Spacetime_Odyssey/S01_Disc${disc}_${DATE_STAMP}"
    mkdir -p "$DISC_DIR"

    echo "    → Disc ${disc}"
    # Move files matching this disc pattern
    find "$STAGING_BASE/Cosmos" -name "*Disc ${disc}_t*.mkv" -exec mv {} "$DISC_DIR/" \;
done

rmdir "$STAGING_BASE/Cosmos"

echo ""

# ============================================
# TV SHOWS - Avatar (needs reorganization)
# ============================================

echo "4. Migrating Avatar The Last Airbender..."

# Avatar is partially processed with naming issues
# Disc 1: Already renamed to S01E##
# Disc 2: Has !ERRtemplate names

AVATAR_BASE="$STAGING_BASE/1-ripped/tv/Avatar_The_Last_Airbender"
mkdir -p "$AVATAR_BASE"

# Disc 1 - already has proper S01E## names, just move
echo "  → Season 1 Disc 1 (already renamed)"
mv "$STAGING_BASE/tv/Avatar_The_Last_Airbender/Season_1_Disc_1" \
   "$AVATAR_BASE/S01_Disc1_${DATE_STAMP}"

# Disc 2 - has !ERRtemplate names, need to rename during move
echo "  → Season 1 Disc 2 (fixing !ERRtemplate names)"
DISC2_DIR="$AVATAR_BASE/S01_Disc2_${DATE_STAMP}"
mkdir -p "$DISC2_DIR"

# Rename !ERRtemplate files to proper track names
cd "$STAGING_BASE/tv/Avatar_The_Last_Airbender/Season_1_Disc_2"
for file in !ERRtemplate_t*.mkv; do
    # Extract track number
    track_num=$(echo "$file" | grep -oP 't\K[0-9]+')
    new_name="Avatar_The_Last_Airbender_t${track_num}.mkv"
    mv "$file" "$DISC2_DIR/$new_name"
    echo "      $file → $new_name"
done

# Clean up old structure
rmdir "$STAGING_BASE/tv/Avatar_The_Last_Airbender/Season_1_Disc_2"
rmdir "$STAGING_BASE/tv/Avatar_The_Last_Airbender"
rmdir "$STAGING_BASE/tv"

echo ""
echo "=========================================="
echo "✓ Migration Complete!"
echo "=========================================="
echo ""
echo "Summary of new structure:"
echo ""
echo "1-ripped/movies/:"
find "$STAGING_BASE/1-ripped/movies" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/  - /'
echo ""
echo "1-ripped/tv/:"
find "$STAGING_BASE/1-ripped/tv" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/  - /'
echo ""
echo "2-remuxed/movies/:"
find "$STAGING_BASE/2-remuxed/movies" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sed 's/^/  - /' || echo "  (none)"
echo ""
echo "3-transcoded/movies/:"
find "$STAGING_BASE/3-transcoded/movies" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sed 's/^/  - /' || echo "  (none)"
echo ""
echo "=========================================="
echo "Next steps:"
echo ""
echo "1-ripped movies - Analyze and organize:"
for dir in "$STAGING_BASE/1-ripped/movies"/*; do
    if [ -d "$dir" ]; then
        echo "  ./analyze-media.sh \"$dir\""
    fi
done
echo ""
echo "1-ripped TV - Organize seasons:"
echo "  ./organize-and-remux-tv.sh \"Cosmos A Spacetime Odyssey\" 01"
echo "  ./organize-and-remux-tv.sh \"Avatar The Last Airbender\" 01"
echo ""
echo "3-transcoded - Verify and promote:"
echo "  # Review in Jellyfin first, then:"
echo "  ./promote-to-ready.sh \"$STAGING_BASE/3-transcoded/movies/How_To_Train_Your_Dragon_${DATE_STAMP}\""
echo ""
