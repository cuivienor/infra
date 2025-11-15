#!/bin/bash
# organize-and-remux-movie.sh - Process movies from 1-ripped to 2-remuxed
# shellcheck disable=SC2155,SC2034
#
# Usage: ./organize-and-remux-movie.sh /path/to/1-ripped/movies/Movie_Name_2024-11-10/
#
# This script will:
# 1. Analyze all MKV files in the folder
# 2. Categorize as main features vs extras (by duration/size)
# 3. Remux to remove non-English/Bulgarian tracks
# 4. Output to 2-remuxed with extras/ subfolder

set -e

INPUT_DIR="$1"
LANGUAGES="eng,bul"  # English and Bulgarian only

if [ -z "$INPUT_DIR" ]; then
    echo "Usage: $0 /path/to/1-ripped/movies/Movie_Name_2024-11-10/"
    echo ""
    echo "Example:"
    echo "  $0 \${STAGING_BASE:-/mnt/staging}/1-ripped/movies/How_To_Train_Your_Dragon_2024-11-10/"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Directory does not exist: $INPUT_DIR"
    exit 1
fi

# Check if required tools are installed
for tool in mkvmerge jq bc; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is not installed"
        exit 1
    fi
done

# Use STAGING_BASE environment variable if set, otherwise default to /mnt/storage/media/staging
STAGING_BASE="${STAGING_BASE:-/mnt/storage/media/staging}"

# Extract movie name and date stamp from folder
FOLDER_NAME=$(basename "$INPUT_DIR")
DATE_STAMP=$(echo "$FOLDER_NAME" | grep -oP '[0-9]{4}-[0-9]{2}-[0-9]{2}$' || echo "")
MOVIE_NAME=$(echo "$FOLDER_NAME" | sed 's/_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}$//')

# Determine output directory
if [ -n "$DATE_STAMP" ]; then
    OUTPUT_DIR="${STAGING_BASE}/2-remuxed/movies/${MOVIE_NAME}_${DATE_STAMP}"
else
    OUTPUT_DIR="${STAGING_BASE}/2-remuxed/movies/${MOVIE_NAME}"
fi

echo "=========================================="
echo "Movie Organization & Remux"
echo "=========================================="
echo "Movie:  $MOVIE_NAME"
echo "Input:  $INPUT_DIR"
echo "Output: $OUTPUT_DIR"
echo "=========================================="
echo ""

# Function to get duration in minutes
get_duration() {
    local file="$1"
    local json=$(mkvmerge -J "$file" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$json" ]; then
        local duration_ns=$(echo "$json" | jq -r '.container.properties.duration // 0')
        echo $((duration_ns / 1000000000 / 60))
    else
        echo "0"
    fi
}

# Function to get size in GB
get_size_gb() {
    local file="$1"
    local size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    echo "scale=2; $size_bytes/1024/1024/1024" | bc
}

# Function to remux and filter tracks
remux_filter_tracks() {
    local input_file="$1"
    local output_file="$2"
    local temp_file="${output_file%.*}_temp.mkv"

    # Get JSON data
    local json_data=$(mkvmerge -J "$input_file" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$json_data" ]; then
        echo "  ✗ Error: Could not read file with mkvmerge"
        return 1
    fi

    # Get all track IDs for English and Bulgarian
    local audio_tracks=$(echo "$json_data" | jq -r '
        [.tracks[] |
         select(.type == "audio" and (.properties.language == "eng" or .properties.language == "bul")) |
         .id] | join(",")')

    local subtitle_tracks=$(echo "$json_data" | jq -r '
        [.tracks[] |
         select(.type == "subtitles" and (.properties.language == "eng" or .properties.language == "bul")) |
         .id] | join(",")')

    # Build mkvmerge command
    local cmd="mkvmerge -o \"$temp_file\""

    # Add audio tracks
    if [ -n "$audio_tracks" ] && [ "$audio_tracks" != "" ]; then
        cmd="$cmd --audio-tracks $audio_tracks"
    else
        cmd="$cmd --no-audio"
    fi

    # Add subtitle tracks
    if [ -n "$subtitle_tracks" ] && [ "$subtitle_tracks" != "" ]; then
        cmd="$cmd --subtitle-tracks $subtitle_tracks"
    else
        cmd="$cmd --no-subtitles"
    fi

    cmd="$cmd \"$input_file\""

    # Execute
    eval $cmd > /dev/null 2>&1

    if [ $? -eq 0 ] && [ -f "$temp_file" ]; then
        # Get sizes
        local orig_size=$(stat -c%s "$input_file" 2>/dev/null || stat -f%z "$input_file" 2>/dev/null || echo "0")
        local new_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null || echo "0")

        if [ "$orig_size" -gt 0 ] && [ "$new_size" -gt 0 ]; then
            local saved=$((orig_size - new_size))
            local saved_mb=$((saved / 1024 / 1024))
            local percent=$((100 - (new_size * 100 / orig_size)))

            mv "$temp_file" "$output_file"
            echo "  ✓ Saved ${saved_mb}MB (${percent}% reduction)"
            return 0
        else
            echo "  ✗ Error: Could not determine file sizes"
            rm -f "$temp_file"
            return 1
        fi
    else
        echo "  ✗ Failed to remux"
        rm -f "$temp_file"
        return 1
    fi
}

# Analyze all MKV files
echo "Analyzing files..."
echo ""

declare -A main_features
declare -A extras

while IFS= read -r -d '' file; do
    filename=$(basename "$file")
    duration=$(get_duration "$file")
    size=$(get_size_gb "$file")

    # Categorize: main feature = >30min AND >5GB
    if (( duration > 30 )) && (( $(echo "$size > 5" | bc -l) )); then
        main_features["$file"]="${duration}min, ${size}GB"
    else
        extras["$file"]="${duration}min, ${size}GB"
    fi
done < <(find "$INPUT_DIR" -name "*.mkv" -type f -not -path "*/discarded/*" -print0 | sort -z)

# Display categorization
echo "MAIN FEATURES (>30min, >5GB):"
if [ ${#main_features[@]} -eq 0 ]; then
    echo "  (none found)"
else
    for file in "${!main_features[@]}"; do
        echo "  ✓ $(basename "$file") - ${main_features[$file]}"
    done
fi

echo ""
echo "EXTRAS (<30min OR <5GB):"
if [ ${#extras[@]} -eq 0 ]; then
    echo "  (none found)"
else
    for file in "${!extras[@]}"; do
        echo "  ⭐ $(basename "$file") - ${extras[$file]}"
    done
fi

echo ""
echo "=========================================="

# Confirm categorization
read -p "Proceed with this categorization? [Y/n]: " -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted"
    exit 0
fi

# Create output directories
echo "Creating output directories..."
mkdir -p "$OUTPUT_DIR"
if [ ${#extras[@]} -gt 0 ]; then
    mkdir -p "$OUTPUT_DIR/extras"
fi

echo ""
echo "=========================================="
echo "Remuxing & Filtering Tracks"
echo "=========================================="
echo "Keeping: English and Bulgarian audio/subtitles"
echo "Removing: All other language tracks"
echo ""

# Process main features
if [ ${#main_features[@]} -gt 0 ]; then
    echo "Processing main features..."
    for file in "${!main_features[@]}"; do
        filename=$(basename "$file")
        output_file="$OUTPUT_DIR/$filename"
        echo "→ $filename"
        remux_filter_tracks "$file" "$output_file"
    done
    echo ""
fi

# Process extras
if [ ${#extras[@]} -gt 0 ]; then
    echo "Processing extras..."
    for file in "${!extras[@]}"; do
        filename=$(basename "$file")
        output_file="$OUTPUT_DIR/extras/$filename"
        echo "→ extras/$filename"
        remux_filter_tracks "$file" "$output_file"
    done
    echo ""
fi

echo "=========================================="
echo "✓ Complete!"
echo "=========================================="
echo "Output directory:"
echo "  $OUTPUT_DIR"
echo ""
echo "Files created:"
if [ ${#main_features[@]} -gt 0 ]; then
    echo "  - ${#main_features[@]} main feature(s)"
fi
if [ ${#extras[@]} -gt 0 ]; then
    echo "  - ${#extras[@]} extra(s) in extras/"
fi

echo ""
echo "Next steps:"
echo "  1. Review in Jellyfin 'Staging - Remuxed' library"
echo "  2. Run transcode: ./transcode-queue.sh \"$OUTPUT_DIR\" 20 software"
echo ""
