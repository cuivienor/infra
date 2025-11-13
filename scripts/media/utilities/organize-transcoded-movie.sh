#!/bin/bash
# organize-transcoded-movie.sh - Organize a transcoded movie with extras
#
# Usage: ./organize-transcoded-movie.sh <source_dir> <movie_name> <year>
#
# This script will:
# 1. Create proper directory structure in 3-transcoded/movies/
# 2. Move main movie file (with _transcoded suffix)
# 3. Move extra files to extras/ subdirectory
# 4. Clean filenames for FileBot processing

set -e

SOURCE_DIR="$1"
MOVIE_NAME="$2"
YEAR="$3"

if [ -z "$SOURCE_DIR" ] || [ -z "$MOVIE_NAME" ]; then
    echo "Usage: $0 <source_dir> <movie_name> [year]"
    echo ""
    echo "Examples:"
    echo "  $0 /mnt/staging/Dragon 'How To Train Your Dragon' 2010"
    echo "  $0 /mnt/staging/Movies/Some_Movie 'Some Movie'"
    echo ""
    echo "This script organizes transcoded movies into the proper structure"
    echo "for FileBot processing in 3-transcoded/movies/"
    exit 1
fi

# Use STAGING_BASE environment variable if set, otherwise auto-detect
if [ -z "$STAGING_BASE" ]; then
    if [ -d "/mnt/staging" ]; then
        STAGING_BASE="/mnt/staging"
    else
        STAGING_BASE="/mnt/storage/media/staging"
    fi
fi

# Sanitize movie name for filesystem
SAFE_NAME=$(echo "$MOVIE_NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')

if [ -n "$YEAR" ]; then
    DEST_DIR="${STAGING_BASE}/3-transcoded/movies/${SAFE_NAME}_${YEAR}"
else
    DEST_DIR="${STAGING_BASE}/3-transcoded/movies/${SAFE_NAME}"
fi

echo "=========================================="
echo "Organize Transcoded Movie"
echo "=========================================="
echo "Movie:  $MOVIE_NAME"
if [ -n "$YEAR" ]; then
    echo "Year:   $YEAR"
fi
echo ""
echo "Source: $SOURCE_DIR"
echo "Dest:   $DEST_DIR"
echo "=========================================="
echo ""

# Check source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory not found: $SOURCE_DIR"
    exit 1
fi

# Create destination directories
mkdir -p "$DEST_DIR"
mkdir -p "$DEST_DIR/extras"

# Find the main transcoded movie file
MAIN_FILE=$(find "$SOURCE_DIR" -maxdepth 1 -name "*_transcoded.mkv" -type f ! -name "*Extra*" | head -1)

if [ -z "$MAIN_FILE" ]; then
    echo "Error: No main transcoded file found (looking for *_transcoded.mkv)"
    echo ""
    echo "Files in source:"
    ls -1 "$SOURCE_DIR"/*.mkv 2>/dev/null || echo "  No MKV files found"
    exit 1
fi

echo "Main movie:"
echo "  $(basename "$MAIN_FILE")"
echo ""

# Move main file
cp -v "$MAIN_FILE" "$DEST_DIR/${MOVIE_NAME}.mkv"

# Find and move extras
EXTRAS_FOUND=0
for extra in "$SOURCE_DIR"/*Extra*_transcoded.mkv; do
    if [ -f "$extra" ]; then
        EXTRAS_FOUND=$((EXTRAS_FOUND + 1))
        EXTRA_BASENAME=$(basename "$extra")
        # Clean up the name (remove _transcoded suffix and movie name prefix)
        EXTRA_NAME=$(echo "$EXTRA_BASENAME" | sed "s/${MOVIE_NAME} - //g" | sed 's/_transcoded\.mkv$/.mkv/')
        echo "Moving extra: $EXTRA_NAME"
        cp -v "$extra" "$DEST_DIR/extras/$EXTRA_NAME"
    fi
done

if [ $EXTRAS_FOUND -gt 0 ]; then
    echo ""
    echo "✓ Moved 1 main file and $EXTRAS_FOUND extras"
else
    echo ""
    echo "✓ Moved 1 main file (no extras found)"
fi

echo ""
echo "=========================================="
echo "Ready for FileBot!"
echo "=========================================="
echo ""
echo "Next step:"
echo "  ~/scripts/filebot-process.sh $DEST_DIR"
echo ""
