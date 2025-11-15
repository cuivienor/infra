#!/bin/bash
# organize-and-remux-tv.sh - Process TV shows from 1-ripped to 2-remuxed
# shellcheck disable=SC2155,SC2034
#
# Usage: ./organize-and-remux-tv.sh "Show Name" 01 [starting_episode]
#
# This script will:
# 1. Find all discs for the specified season
# 2. Scan disc root for main episodes (in natural order)
# 3. Scan extras/ subdirectory for bonus content
# 4. Ignore discarded/ subdirectory completely
# 5. Auto-number episodes sequentially across all discs
# 6. Remux all files with track filtering (eng/bul only)
# 7. Output to 2-remuxed/tv/Show_Name/Season_##/
#
# PREREQUISITE: You must manually organize files in each disc directory:
#   - Main episodes → keep in disc root
#   - Bonus content → move to extras/ subdirectory
#   - Junk files → move to discarded/ subdirectory

set -e

SHOW_NAME="$1"
SEASON_NUM="$2"
START_EPISODE="${3:-1}"  # Optional starting episode number

if [ -z "$SHOW_NAME" ] || [ -z "$SEASON_NUM" ]; then
    echo "Usage: $0 \"Show Name\" <season-number> [starting-episode]"
    echo ""
    echo "Examples:"
    echo "  $0 \"Avatar The Last Airbender\" 01"
    echo "  $0 \"Avatar The Last Airbender\" 01 5  # Start at E05"
    echo ""
    echo "IMPORTANT: Before running, manually organize files in each disc directory:"
    echo "  - Main episodes → keep in disc root"
    echo "  - Bonus content → move to extras/ subdirectory"
    echo "  - Junk files → move to discarded/ subdirectory"
    echo ""
    echo "This script will process ALL discs for the specified season."
    exit 1
fi

# Check if required tools are installed
for tool in mkvmerge jq bc; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is not installed"
        exit 1
    fi
done

# Sanitize show name for filesystem
SAFE_SHOW=$(echo "$SHOW_NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')

# Use STAGING_BASE environment variable if set, otherwise default to /mnt/storage/media/staging
STAGING_BASE="${STAGING_BASE:-/mnt/storage/media/staging}"

# Find all disc folders for this season
BASE_DIR="${STAGING_BASE}/1-ripped/tv/${SAFE_SHOW}"
DISC_PATTERN="S${SEASON_NUM}_Disc*"

if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Show directory not found: $BASE_DIR"
    echo ""
    echo "Hint: Make sure STAGING_BASE is set correctly."
    echo "Current STAGING_BASE: $STAGING_BASE"
    echo ""
    echo "Try: export STAGING_BASE=/mnt/staging"
    exit 1
fi

mapfile -t disc_folders < <(find "$BASE_DIR" -maxdepth 1 -type d -name "$DISC_PATTERN" | sort)

if [ ${#disc_folders[@]} -eq 0 ]; then
    echo "Error: No discs found for Season $SEASON_NUM in $BASE_DIR"
    echo ""
    echo "Looking for pattern: $DISC_PATTERN"
    echo "Available folders:"
    for dir in "$BASE_DIR"/S*/; do
        [ -d "$dir" ] && basename "$dir"
    done || echo "  (none)"
    exit 1
fi

echo "=========================================="
echo "TV Show Remux (Manual Pre-Organization)"
echo "=========================================="
echo "Show:           $SHOW_NAME"
echo "Season:         $SEASON_NUM"
echo "Start Episode:  E$(printf '%02d' $START_EPISODE)"
echo ""
echo "Found ${#disc_folders[@]} disc(s):"
for disc in "${disc_folders[@]}"; do
    episodes=$(find "$disc" -maxdepth 1 -name "*.mkv" -type f | wc -l)
    extras=$(find "$disc/extras" -name "*.mkv" -type f 2>/dev/null | wc -l)
    discarded=$(find "$disc/discarded" -name "*.mkv" -type f 2>/dev/null | wc -l)
    echo "  - $(basename "$disc"): $episodes episodes, $extras extras, $discarded discarded"
done
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
        echo "  ✗ Error reading file"
        return 1
    fi

    # Get track IDs for English and Bulgarian
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

    if [ -n "$audio_tracks" ] && [ "$audio_tracks" != "" ]; then
        cmd="$cmd --audio-tracks $audio_tracks"
    else
        cmd="$cmd --no-audio"
    fi

    if [ -n "$subtitle_tracks" ] && [ "$subtitle_tracks" != "" ]; then
        cmd="$cmd --subtitle-tracks $subtitle_tracks"
    else
        cmd="$cmd --no-subtitles"
    fi

    cmd="$cmd \"$input_file\""

    # Execute (capture output for debugging)
    local mkvmerge_output
    mkvmerge_output=$(eval $cmd 2>&1)
    local mkvmerge_exit=$?

    if [ $mkvmerge_exit -eq 0 ] && [ -f "$temp_file" ]; then
        mv "$temp_file" "$output_file"
        return 0
    else
        echo "  ✗ mkvmerge failed (exit code: $mkvmerge_exit)"
        if [ -n "$mkvmerge_output" ]; then
            echo "  Error: $(echo "$mkvmerge_output" | head -2)"
        fi
        rm -f "$temp_file"
        return 1
    fi
}

# Build lists of episode and extra files
echo "Scanning organized files..."
echo ""

declare -a episode_files
declare -a extra_files

# Scan each disc for episodes (root level) and extras (extras/ subdirectory)
for disc_dir in "${disc_folders[@]}"; do
    disc_name=$(basename "$disc_dir")

    # Find episodes in disc root (sorted naturally by filename)
    while IFS= read -r -d '' file; do
        episode_files+=("$file")
    done < <(find "$disc_dir" -maxdepth 1 -name "*.mkv" -type f -print0 | sort -z)

    # Find extras in extras/ subdirectory (if it exists)
    if [ -d "$disc_dir/extras" ]; then
        while IFS= read -r -d '' file; do
            extra_files+=("$file")
        done < <(find "$disc_dir/extras" -name "*.mkv" -type f -print0 | sort -z)
    fi
done

total_episodes=${#episode_files[@]}
total_extras=${#extra_files[@]}

if [ $total_episodes -eq 0 ]; then
    echo "Error: No episode files found in disc root directories!"
    echo ""
    echo "Make sure you've organized files properly:"
    echo "  - Main episodes should be in disc root"
    echo "  - Extras should be in extras/ subdirectory"
    echo "  - Discarded files should be in discarded/ subdirectory"
    exit 1
fi

echo "Found:"
echo "  - $total_episodes episodes (in disc roots)"
echo "  - $total_extras extras (in extras/ subdirectories)"
echo ""

# Display episode mapping preview
echo "=========================================="
echo "Episode Mapping Preview"
echo "=========================================="
echo ""

ep_num=$START_EPISODE

for file in "${episode_files[@]}"; do
    duration=$(get_duration "$file")
    size=$(get_size_gb "$file")
    filename=$(basename "$file")
    disc_name=$(basename "$(dirname "$file")")

    printf "S%02dE%02d ← %-40s (%dm, %.2fG) [%s]\n" \
        "$SEASON_NUM" "$ep_num" "$filename" "$duration" "$size" "$disc_name"
    ep_num=$((ep_num + 1))
done

if [ $total_extras -gt 0 ]; then
    echo ""
    echo "Extras (will preserve original filenames):"
    for file in "${extra_files[@]}"; do
        duration=$(get_duration "$file")
        size=$(get_size_gb "$file")
        filename=$(basename "$file")
        disc_name=$(basename "$(dirname "$(dirname "$file")")")

        printf "  %-40s (%dm, %.2fG) [%s]\n" \
            "$filename" "$duration" "$size" "$disc_name"
    done
fi

echo ""
echo "=========================================="
echo ""
read -p "Proceed with remuxing? [Y/n]: " -r
echo

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted"
    exit 0
fi

# Process files
OUTPUT_DIR="${STAGING_BASE}/2-remuxed/tv/${SAFE_SHOW}/Season_${SEASON_NUM}"

echo ""
echo "=========================================="
echo "Remuxing & Track Filtering"
echo "=========================================="
echo "Output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

if [ $total_extras -gt 0 ]; then
    mkdir -p "$OUTPUT_DIR/extras"
fi

echo ""
echo "Keeping: English and Bulgarian audio/subtitles"
echo "Removing: All other language tracks"
echo ""

total_files=$((total_episodes + total_extras))
processed=0
failed=0

# Process episodes
echo "Processing episodes..."
ep_num=$START_EPISODE

for input_file in "${episode_files[@]}"; do
    output_file=$(printf "$OUTPUT_DIR/S%02dE%02d.mkv" "$SEASON_NUM" "$ep_num")
    echo "[$((processed+failed+1))/$total_files] S${SEASON_NUM}E$(printf '%02d' $ep_num) ← $(basename "$input_file")"

    if remux_filter_tracks "$input_file" "$output_file"; then
        processed=$((processed + 1))
    else
        echo "  ✗ Failed to remux"
        failed=$((failed + 1))
    fi
    ep_num=$((ep_num + 1))
done

# Process extras
if [ $total_extras -gt 0 ]; then
    echo ""
    echo "Processing extras..."

    for input_file in "${extra_files[@]}"; do
        filename=$(basename "$input_file")
        output_file="$OUTPUT_DIR/extras/$filename"
        echo "[$((processed+failed+1))/$total_files] Extra ← $filename"

        if remux_filter_tracks "$input_file" "$output_file"; then
            processed=$((processed + 1))
        else
            echo "  ✗ Failed to remux"
            failed=$((failed + 1))
        fi
    done
fi

echo ""
echo "=========================================="
echo "✓ Complete!"
echo "=========================================="
echo "Output directory:"
echo "  $OUTPUT_DIR"
echo ""
echo "Results:"
echo "  - Successfully processed: $processed files"
if [ $failed -gt 0 ]; then
    echo "  - Failed: $failed files"
fi
echo ""

# List output
created_episodes=$(find "$OUTPUT_DIR" -maxdepth 1 -name "S*.mkv" -type f | wc -l)
created_extras=$(find "$OUTPUT_DIR/extras" -name "*.mkv" -type f 2>/dev/null | wc -l)

echo "Files created:"
echo "  - $created_episodes episodes"
if [ $created_extras -gt 0 ]; then
    echo "  - $created_extras extras in extras/"
fi

echo ""
echo "Next steps:"
echo "  1. Review output files for quality"
echo "  2. (Optional) Transcode if needed: ./transcode-queue.sh \"$OUTPUT_DIR\" 20 software"
echo "  3. Use FileBot to add episode titles and metadata"
echo "  4. Move to final library location"
echo ""
