#!/bin/bash
# MakeMKV Disc Ripper Helper
# Usage: ./rip-disc.sh <type> <name> [disc-info]
#
# Examples:
#   ./rip-disc.sh movie "The Matrix"
#   ./rip-disc.sh movie "The Matrix Reloaded"
#   ./rip-disc.sh show "Avatar The Last Airbender" "Season 1 Disc 1"
#   ./rip-disc.sh collection "The Matrix Collection" "Disc 1"

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <type> <name> [disc-info]"
    echo ""
    echo "Types:"
    echo "  movie      - Single movie (no disc info needed)"
    echo "  show       - TV show (requires disc info like 'S01 Disc1')"
    echo ""
    echo "Examples:"
    echo "  $0 movie \"The Matrix\""
    echo "  $0 show \"Avatar The Last Airbender\" \"S01 Disc1\""
    echo "  $0 show \"Avatar The Last Airbender\" \"S02 Disc2\""
    exit 1
fi

TYPE="$1"
NAME="$2"
DISC_INFO="$3"

# Validate type
if [[ ! "$TYPE" =~ ^(movie|show)$ ]]; then
    echo "Error: Type must be 'movie' or 'show'"
    exit 1
fi

# Require disc info for shows
if [[ "$TYPE" == "show" ]] && [ -z "$DISC_INFO" ]; then
    echo "Error: Disc info required for TV shows"
    echo "Example: $0 $TYPE \"$NAME\" \"S01 Disc1\""
    exit 1
fi

# Create safe directory names
SAFE_NAME=$(echo "$NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')

# Get date stamp
DATE_STAMP=$(date +%Y-%m-%d)

# Determine output path based on type
case "$TYPE" in
    movie)
        OUTPUT_DIR="/mnt/storage/media/staging/1-ripped/movies/${SAFE_NAME}_${DATE_STAMP}"
        DISPLAY_INFO="Movie: $NAME"
        ;;
    show)
        SAFE_DISC=$(echo "$DISC_INFO" | tr ' ' '_' | tr -cd '[:alnum:]_-')
        OUTPUT_DIR="/mnt/storage/media/staging/1-ripped/tv/${SAFE_NAME}/${SAFE_DISC}_${DATE_STAMP}"
        DISPLAY_INFO="Show: $NAME | Disc: $DISC_INFO"
        ;;
esac

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "=========================================="
echo "MakeMKV Disc Ripper"
echo "=========================================="
echo "$DISPLAY_INFO"
echo "Output: $OUTPUT_DIR"
echo "=========================================="
echo ""

# Get disc info first
echo "Analyzing disc..."
makemkvcon info disc:0

echo ""
echo "Starting rip of ALL titles..."
echo "This will take 30-90 minutes depending on disc size"
echo ""

# Rip all titles
makemkvcon mkv disc:0 all "$OUTPUT_DIR"

echo ""
echo "=========================================="
echo "Rip complete!"
echo "Files saved to: $OUTPUT_DIR"
echo "=========================================="

# For TV shows, rename files to include disc identifier
if [ "$TYPE" == "show" ]; then
    echo ""
    echo "Adding disc identifier to filenames..."
    
    # Extract disc number from DISC_INFO (e.g., "S01 Disc1" → "Disc1")
    DISC_ID=$(echo "$DISC_INFO" | tr ' ' '_' | grep -oP '(S[0-9]+_)?Disc[0-9]+' || echo "Disc")
    
    cd "$OUTPUT_DIR"
    
    # Rename all files to include show name and disc ID
    # Pattern: title_t00.mkv → ShowName_DiscX_t00.mkv
    for file in *.mkv; do
        if [ -f "$file" ]; then
            # Extract track number from filename
            if [[ "$file" =~ _t([0-9]+)\.mkv ]]; then
                track_num="${BASH_REMATCH[1]}"
                new_name="${SAFE_NAME}_${DISC_ID}_t${track_num}.mkv"
                
                if [ "$file" != "$new_name" ]; then
                    mv "$file" "$new_name"
                    echo "  Renamed: $file → $new_name"
                fi
            fi
        fi
    done
    
    cd - > /dev/null
    
    echo ""
    echo "✓ Files renamed with disc identifier"
fi

echo ""
ls -lh "$OUTPUT_DIR"
echo ""
