#!/bin/bash
# organize-and-remux-tv.sh - Process TV shows from 1-ripped to 2-remuxed
#
# Usage: ./organize-and-remux-tv.sh "Show Name" 01
#
# This script will:
# 1. Find all discs for the specified season
# 2. List all MKV files across discs in order
# 3. Interactive extra identification
# 4. Auto-number remaining files as episodes
# 5. Remux all files with track filtering (eng/bul only)
# 6. Output to 2-remuxed/tv/Show_Name/Season_##/

set -e

SHOW_NAME="$1"
SEASON_NUM="$2"
LANGUAGES="eng,bul"  # English and Bulgarian only

if [ -z "$SHOW_NAME" ] || [ -z "$SEASON_NUM" ]; then
    echo "Usage: $0 \"Show Name\" <season-number>"
    echo ""
    echo "Examples:"
    echo "  $0 \"Avatar The Last Airbender\" 01"
    echo "  $0 \"Breaking Bad\" 03"
    echo ""
    echo "This will process ALL discs for the specified season."
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

# Find all disc folders for this season
BASE_DIR="/mnt/storage/media/staging/1-ripped/tv/${SAFE_SHOW}"
DISC_PATTERN="S${SEASON_NUM}_Disc*"

if [ ! -d "$BASE_DIR" ]; then
    echo "Error: Show directory not found: $BASE_DIR"
    exit 1
fi

mapfile -t disc_folders < <(find "$BASE_DIR" -maxdepth 1 -type d -name "$DISC_PATTERN" | sort)

if [ ${#disc_folders[@]} -eq 0 ]; then
    echo "Error: No discs found for Season $SEASON_NUM in $BASE_DIR"
    echo ""
    echo "Looking for pattern: $DISC_PATTERN"
    echo "Available folders:"
    ls -1 "$BASE_DIR" | grep "^S" || echo "  (none)"
    exit 1
fi

echo "=========================================="
echo "TV Show Organization"
echo "=========================================="
echo "Show:   $SHOW_NAME"
echo "Season: $SEASON_NUM"
echo ""
echo "Found ${#disc_folders[@]} disc(s):"
for disc in "${disc_folders[@]}"; do
    count=$(find "$disc" -maxdepth 1 -name "*.mkv" -type f | wc -l)
    echo "  - $(basename "$disc") ($count files)"
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
    
    # Execute
    eval $cmd > /dev/null 2>&1
    
    if [ $? -eq 0 ] && [ -f "$temp_file" ]; then
        mv "$temp_file" "$output_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Build list of all MKV files with metadata
echo "Analyzing all files..."
echo ""

declare -a all_files
file_idx=1

for disc_dir in "${disc_folders[@]}"; do
    disc_name=$(basename "$disc_dir")
    
    while IFS= read -r -d '' file; do
        duration=$(get_duration "$file")
        size=$(get_size_gb "$file")
        track_num=$(basename "$file" | grep -oP 't\K[0-9]+' || echo "??")
        
        # Store: index|disc_name|track_num|duration|size|full_path
        all_files+=("${file_idx}|${disc_name}|${track_num}|${duration}|${size}|${file}")
        ((file_idx++))
    done < <(find "$disc_dir" -maxdepth 1 -name "*.mkv" -type f -print0 | sort -z)
done

total_files=${#all_files[@]}

if [ $total_files -eq 0 ]; then
    echo "Error: No MKV files found in disc folders"
    exit 1
fi

# Display table
echo "Files in disc/track order:"
echo ""
printf "%3s | %-25s | %5s | %8s | %6s | %s\n" "#" "Disc" "Track" "Duration" "Size" "Notes"
echo "----+---------------------------+-------+----------+--------+-------"

for entry in "${all_files[@]}"; do
    IFS='|' read -r idx disc track dur size filepath <<< "$entry"
    
    # Flag potential extras (duration outliers)
    notes=""
    if (( dur < 15 )); then
        notes="⚠️ SHORT"
    elif (( dur > 60 )); then
        notes="⚠️ LONG"
    fi
    
    printf "%3d | %-25s | t%-4s | %7dm | %5.2fG | %s\n" "$idx" "$disc" "$track" "$dur" "$size" "$notes"
done

echo ""
echo "=========================================="
echo "Step 1: Identify Extras"
echo "=========================================="
echo ""

# Detect potential extras automatically
echo "Potential extras detected (unusual duration):"
has_suggestions=false
for entry in "${all_files[@]}"; do
    IFS='|' read -r idx disc track dur size filepath <<< "$entry"
    if (( dur < 15 )) || (( dur > 60 )); then
        echo "  #$idx: $(basename "$filepath") (${dur}min)"
        has_suggestions=true
    fi
done

if [ "$has_suggestions" = false ]; then
    echo "  (none detected - all files similar duration)"
fi

echo ""
read -p "Enter file numbers to mark as extras (comma-separated, or 'n' for none): " extra_nums

# Store extras mapping: file_idx -> custom_name
declare -A extras_map

if [[ "$extra_nums" != "n" ]] && [[ -n "$extra_nums" ]]; then
    IFS=',' read -ra nums <<< "$extra_nums"
    for num in "${nums[@]}"; do
        num=$(echo "$num" | xargs)  # trim whitespace
        
        # Find the entry
        for entry in "${all_files[@]}"; do
            IFS='|' read -r idx disc track dur size filepath <<< "$entry"
            if [ "$idx" = "$num" ]; then
                echo ""
                echo "Extra #$num: $(basename "$filepath") (${dur}min)"
                read -p "  Name for this extra [default: Extra_$num]: " extra_name
                extra_name=${extra_name:-"Extra_$num"}
                extras_map[$num]="$extra_name"
                break
            fi
        done
    done
fi

echo ""
echo "=========================================="
echo "Step 2: Episode Numbering"
echo "=========================================="
echo ""

# Count episodes (non-extras)
episode_count=0
for entry in "${all_files[@]}"; do
    IFS='|' read -r idx disc track dur size filepath <<< "$entry"
    if [[ -z "${extras_map[$idx]}" ]]; then
        ((episode_count++))
    fi
done

echo "Files to number as episodes: $episode_count"
echo "Extras: ${#extras_map[@]}"
echo ""

read -p "Starting episode number [S${SEASON_NUM}E01]: " start_ep
start_ep=${start_ep:-"S${SEASON_NUM}E01"}

# Extract episode number from input (e.g., S01E05 -> 5)
ep_num=$(echo "$start_ep" | grep -oP 'E\K[0-9]+' || echo "1")

# Show mapping preview
echo ""
echo "Episode mapping preview:"
echo ""

for entry in "${all_files[@]}"; do
    IFS='|' read -r idx disc track dur size filepath <<< "$entry"
    
    if [[ -n "${extras_map[$idx]}" ]]; then
        echo "  EXTRA  ← #$idx (extras/${extras_map[$idx]}.mkv)"
    else
        printf "  S%02dE%02d ← #%d (%s/t%s, %dm)\n" "$SEASON_NUM" "$ep_num" "$idx" "$disc" "$track" "$dur"
        ((ep_num++))
    fi
done

echo ""
read -p "Confirm this mapping? [Y/n]: " -r
echo

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted"
    exit 0
fi

# Process files
OUTPUT_DIR="/mnt/storage/media/staging/2-remuxed/tv/${SAFE_SHOW}/Season_${SEASON_NUM}"

echo ""
echo "=========================================="
echo "Step 3: Remuxing & Filtering"
echo "=========================================="
echo "Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/extras"

echo ""
echo "Keeping: English and Bulgarian audio/subtitles"
echo "Removing: All other language tracks"
echo ""

# Reset episode counter
ep_num=$(echo "$start_ep" | grep -oP 'E\K[0-9]+' || echo "1")
processed=0
failed=0

for entry in "${all_files[@]}"; do
    IFS='|' read -r idx disc track dur size filepath <<< "$entry"
    
    if [[ -n "${extras_map[$idx]}" ]]; then
        # Process as extra
        output_file="$OUTPUT_DIR/extras/${extras_map[$idx]}.mkv"
        echo "[$((processed+1))/$total_files] Remuxing extra: ${extras_map[$idx]}.mkv"
    else
        # Process as episode
        output_file=$(printf "$OUTPUT_DIR/S%02dE%02d.mkv" "$SEASON_NUM" "$ep_num")
        echo "[$((processed+1))/$total_files] Remuxing episode: S${SEASON_NUM}E$(printf '%02d' $ep_num).mkv"
        ((ep_num++))
    fi
    
    if remux_filter_tracks "$filepath" "$output_file"; then
        ((processed++))
    else
        echo "  ✗ Failed to remux"
        ((failed++))
    fi
done

echo ""
echo "=========================================="
echo "✓ Complete!"
echo "=========================================="
echo "Output directory:"
echo "  $OUTPUT_DIR"
echo ""
echo "Results:"
echo "  - Successfully processed: $((processed - failed)) files"
if [ $failed -gt 0 ]; then
    echo "  - Failed: $failed files"
fi
echo ""

# List output
echo "Files created:"
episode_files=$(find "$OUTPUT_DIR" -maxdepth 1 -name "S*.mkv" -type f | wc -l)
extra_files=$(find "$OUTPUT_DIR/extras" -name "*.mkv" -type f 2>/dev/null | wc -l)

echo "  - $episode_files episodes"
if [ $extra_files -gt 0 ]; then
    echo "  - $extra_files extras in extras/"
fi

echo ""
echo "Next steps:"
echo "  1. Review in Jellyfin 'Staging - Remuxed' library"
echo "  2. Run transcode: ./transcode-queue.sh \"$OUTPUT_DIR\" 20 software"
echo ""
