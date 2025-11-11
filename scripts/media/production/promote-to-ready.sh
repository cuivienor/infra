#!/bin/bash
# promote-to-ready.sh - Promote verified transcodes from 3-transcoded to 4-ready
#
# Usage: ./promote-to-ready.sh /path/to/3-transcoded/movies/Movie_Name_2024-11-10/
#
# This script will:
# 1. Preview what will be moved
# 2. Remove date stamps from folder names
# 3. Copy files to 4-ready (for safety)
# 4. Optionally delete source after confirmation

set -e

INPUT_DIR="$1"

if [ -z "$INPUT_DIR" ]; then
    echo "Usage: $0 /path/to/3-transcoded/[type]/[folder]"
    echo ""
    echo "Examples:"
    echo "  $0 /staging/3-transcoded/movies/Movie_Name_2024-11-10/"
    echo "  $0 /staging/3-transcoded/tv/Show_Name/Season_01/"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Directory does not exist: $INPUT_DIR"
    exit 1
fi

# Verify this is from 3-transcoded
if [[ ! "$INPUT_DIR" =~ staging/3-transcoded ]]; then
    echo "Error: This script is designed for staging/3-transcoded paths"
    echo "Your path: $INPUT_DIR"
    exit 1
fi

# Detect type (movies or tv)
if [[ "$INPUT_DIR" =~ /movies/ ]]; then
    TYPE="movies"
elif [[ "$INPUT_DIR" =~ /tv/ ]]; then
    TYPE="tv"
else
    echo "Error: Cannot determine type (movies or tv) from path"
    exit 1
fi

# Build output path
FOLDER_NAME=$(basename "$INPUT_DIR")

if [[ "$TYPE" == "tv" ]]; then
    # For TV: preserve Show/Season structure
    SHOW_NAME=$(basename "$(dirname "$INPUT_DIR")")
    SEASON_NAME="$FOLDER_NAME"  # e.g., Season_01
    
    # No date stamp removal for TV seasons
    OUTPUT_DIR="/mnt/storage/media/staging/4-ready/tv/${SHOW_NAME}/${SEASON_NAME}"
else
    # For movies: clean the date stamp
    CLEAN_NAME=$(echo "$FOLDER_NAME" | sed 's/_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$//')
    
    # If no date stamp found, use original name
    if [ "$CLEAN_NAME" = "$FOLDER_NAME" ]; then
        OUTPUT_DIR="/mnt/storage/media/staging/4-ready/movies/${FOLDER_NAME}"
    else
        OUTPUT_DIR="/mnt/storage/media/staging/4-ready/movies/${CLEAN_NAME}"
    fi
fi

echo "=========================================="
echo "Promote to Ready"
echo "=========================================="
echo "Type:  $TYPE"
echo "From:  $INPUT_DIR"
echo "To:    $OUTPUT_DIR"
echo ""

# Check if output already exists
if [ -d "$OUTPUT_DIR" ]; then
    echo "⚠️  Warning: Output directory already exists!"
    echo "Files may be overwritten."
    echo ""
    read -p "Continue anyway? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 0
    fi
    echo ""
fi

# Count and show files to be promoted
echo "Files to be promoted:"
file_count=0
total_size=0

while IFS= read -r -d '' file; do
    size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    size_h=$(du -h "$file" | cut -f1)
    rel_path="${file#$INPUT_DIR/}"
    
    echo "  $rel_path ($size_h)"
    
    ((file_count++))
    total_size=$((total_size + size_bytes))
done < <(find "$INPUT_DIR" -type f -name "*.mkv" -print0 | sort -z)

if [ $file_count -eq 0 ]; then
    echo "  (no MKV files found)"
    echo ""
    echo "Aborted - nothing to promote"
    exit 1
fi

total_size_gb=$(awk "BEGIN {printf \"%.2f\", $total_size/1024/1024/1024}")

echo ""
echo "Total: $file_count file(s), ${total_size_gb}GB"
echo ""
echo "=========================================="

read -p "Proceed with promotion? [y/N]: " -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 0
fi

# Copy files
echo ""
echo "Copying files to 4-ready..."
echo ""

mkdir -p "$OUTPUT_DIR"

rsync -av --progress "$INPUT_DIR/" "$OUTPUT_DIR/"
rsync_exit=$?

if [ $rsync_exit -eq 0 ]; then
    echo ""
    echo "✓ Files copied successfully"
    echo ""
    
    # Verify file count matches
    copied_count=$(find "$OUTPUT_DIR" -type f -name "*.mkv" | wc -l)
    
    if [ $copied_count -eq $file_count ]; then
        echo "✓ Verified: All $file_count files present in output"
        echo ""
        
        read -p "Delete source files from 3-transcoded? [y/N]: " -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Deleting source directory..."
            rm -rf "$INPUT_DIR"
            echo "✓ Source files deleted"
        else
            echo "Source files kept at: $INPUT_DIR"
        fi
    else
        echo "⚠️  Warning: File count mismatch!"
        echo "   Expected: $file_count"
        echo "   Found:    $copied_count"
        echo ""
        echo "Source files NOT deleted for safety"
    fi
else
    echo ""
    echo "✗ Copy failed (rsync exit code: $rsync_exit)"
    echo "Source files untouched"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ Promotion Complete!"
echo "=========================================="
echo "Ready for FileBot: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "  1. Review in Jellyfin 'Staging - Ready' library"
echo "  2. Process with FileBot: ./filebot-process.sh \"$OUTPUT_DIR\""
echo ""
