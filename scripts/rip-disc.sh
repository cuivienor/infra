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
    echo "  show       - TV show (requires disc info)"
    echo "  collection - Movie collection (requires disc info)"
    echo ""
    echo "Examples:"
    echo "  $0 movie \"The Matrix\""
    echo "  $0 show \"Avatar The Last Airbender\" \"Season 1 Disc 1\""
    echo "  $0 collection \"The Matrix Collection\" \"Disc 1\""
    exit 1
fi

TYPE="$1"
NAME="$2"
DISC_INFO="$3"

# Validate type
if [[ ! "$TYPE" =~ ^(movie|show|collection)$ ]]; then
    echo "Error: Type must be 'movie', 'show', or 'collection'"
    exit 1
fi

# Require disc info for shows and collections
if [[ "$TYPE" == "show" || "$TYPE" == "collection" ]] && [ -z "$DISC_INFO" ]; then
    echo "Error: Disc info required for type '$TYPE'"
    echo "Example: $0 $TYPE \"$NAME\" \"Season 1 Disc 1\""
    exit 1
fi

# Create safe directory names
SAFE_NAME=$(echo "$NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')

# Determine output path based on type
case "$TYPE" in
    movie)
        OUTPUT_DIR="/mnt/storage/media/staging/movies/${SAFE_NAME}"
        DISPLAY_INFO="Movie: $NAME"
        ;;
    show)
        SAFE_DISC=$(echo "$DISC_INFO" | tr ' ' '_' | tr -cd '[:alnum:]_-')
        OUTPUT_DIR="/mnt/storage/media/staging/tv/${SAFE_NAME}/${SAFE_DISC}"
        DISPLAY_INFO="Show: $NAME | Disc: $DISC_INFO"
        ;;
    collection)
        SAFE_DISC=$(echo "$DISC_INFO" | tr ' ' '_' | tr -cd '[:alnum:]_-')
        OUTPUT_DIR="/mnt/storage/media/staging/collections/${SAFE_NAME}/${SAFE_DISC}"
        DISPLAY_INFO="Collection: $NAME | Disc: $DISC_INFO"
        ;;
esac

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Configure MakeMKV output filename (simple title-based naming)
# This avoids the !ERRtemplate issue
mkdir -p ~/.MakeMKV

# Preserve existing settings (like license key) and only update filename template
if [ -f ~/.MakeMKV/settings.conf ]; then
    # Remove old filename setting if exists
    sed -i '/app_DefaultOutputFileName=/d' ~/.MakeMKV/settings.conf
    # Add new filename setting
    echo 'app_DefaultOutputFileName="{t}"' >> ~/.MakeMKV/settings.conf
else
    # Create new settings file
    cat > ~/.MakeMKV/settings.conf << 'EOF'
app_DefaultOutputFileName="{t}"
app_DefaultSelectionString="+sel:all"
EOF
fi

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
ls -lh "$OUTPUT_DIR"

# For TV shows, offer to rename files to episode numbers
if [ "$TYPE" == "show" ]; then
    echo ""
    echo "Note: TV show files may need renaming for Jellyfin."
    echo "Current files use disc titles (often not helpful)."
    echo ""
    echo "To rename manually:"
    echo "  cd '$OUTPUT_DIR'"
    echo "  # Rename files to match episode numbers"
    echo "  # Example: mv 'title_t00.mkv' 'S01E01.mkv'"
    echo ""
fi
