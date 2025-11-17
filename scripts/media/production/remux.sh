#!/bin/bash
# Media Remux - Process organized media from 1-ripped to 2-remuxed
# Usage: ./remux.sh -t <type> -n <name> [-s <season>]
#
# Examples:
#   ./remux.sh -t movie -n "The Matrix"
#   ./remux.sh -t show -n "Avatar The Last Airbender" -s 2
#   ./remux.sh --type show --name "Breaking Bad" --season 3
#
# This script will:
# 1. Read from manually organized directories in 1-ripped
# 2. For TV: Consolidate all discs for a season into one folder
# 3. Preserve extras categories (Jellyfin-compatible folder structure)
# 4. Remux all files to filter tracks (eng/bul only)
# 5. Output to 2-remuxed with proper structure
#
# PREREQUISITE: You must manually organize files first:
#   TV Shows:
#     - Episodes → _episodes/ (renamed as 01.mkv, 02.mkv, etc.)
#     - Extras → _extras/{category}/ (with descriptive names)
#     - Discarded → _discarded/ (ignored by this script)
#   Movies:
#     - Main feature → _main/ (single file)
#     - Extras → _extras/{category}/ (with descriptive names)
#     - Discarded → _discarded/ (ignored by this script)
#
# State Management:
#   - Creates .remux/ directory with status, logs, and metadata
#   - Creates symlink in ~/active-jobs/ for global visibility
#   - Status: in_progress → completed or failed
#
# Monitoring:
#   ls ~/active-jobs/                    # See all active jobs
#   cat ~/active-jobs/*/status           # Check status
#   tail -f ~/active-jobs/*/remux.log    # Follow logs

set -e

# Default values
TYPE=""
NAME=""
SEASON=""

# Global state directory for active jobs
ACTIVE_JOBS_DIR="$HOME/active-jobs"

# Standardized media path
MEDIA_BASE="/mnt/media"

# Help function
show_help() {
    cat << EOF
Usage: $0 -t <type> -n <name> [-s <season>]

Options:
  -t, --type <type>       Media type: 'movie' or 'show' (required)
  -n, --name <name>       Title of the movie or show (required)
  -s, --season <number>   Season number (required for shows)
  -h, --help              Show this help message

Examples:
  $0 -t movie -n "The Matrix"
  $0 -t show -n "Avatar The Last Airbender" -s 2
  $0 --type show --name "Breaking Bad" --season 3

Prerequisites:
  TV Shows: Manually organize files in each disc directory:
    - Episodes → _episodes/ (as 01.mkv, 02.mkv, etc.)
    - Extras → _extras/{category}/ (with descriptive names)
    - Discarded → _discarded/

  Movies: Manually organize files in the movie directory:
    - Main feature → _main/ (single file)
    - Extras → _extras/{category}/ (with descriptive names)
    - Discarded → _discarded/

State Management:
  Job state is tracked in OUTPUT_DIR/.remux/
  Active jobs are symlinked in ~/active-jobs/

Monitoring:
  ls ~/active-jobs/                    # See all active jobs
  cat ~/active-jobs/*/status           # Check status of all jobs
  tail -f ~/active-jobs/*/remux.log    # Follow logs of all jobs
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            TYPE="$2"
            shift 2
            ;;
        -n|--name)
            NAME="$2"
            shift 2
            ;;
        -s|--season)
            SEASON="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown option $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$TYPE" ] || [ -z "$NAME" ]; then
    echo "Error: --type and --name are required"
    echo "Use -h or --help for usage information"
    exit 1
fi

# Validate type
if [[ ! "$TYPE" =~ ^(movie|show)$ ]]; then
    echo "Error: Type must be 'movie' or 'show'"
    exit 1
fi

# Require season for shows
if [[ "$TYPE" == "show" ]]; then
    if [ -z "$SEASON" ]; then
        echo "Error: --season is required for TV shows"
        echo "Example: $0 -t show -n \"$NAME\" -s 1"
        exit 1
    fi

    # Validate season is a number
    if ! [[ "$SEASON" =~ ^[0-9]+$ ]]; then
        echo "Error: Season must be a number"
        exit 1
    fi
fi

# Verify mount exists
if [ ! -d "$MEDIA_BASE/staging" ]; then
    echo "Error: Media mount not found at $MEDIA_BASE/staging"
    echo "Expected mount: $MEDIA_BASE → /mnt/storage/media"
    exit 1
fi

# Check if required tools are installed
for tool in mkvmerge jq bc; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is not installed"
        exit 1
    fi
done

# Create safe directory names
SAFE_NAME=$(echo "$NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')

# Define paths based on type
case "$TYPE" in
    movie)
        INPUT_DIR="${MEDIA_BASE}/staging/1-ripped/movies/${SAFE_NAME}"
        OUTPUT_DIR="${MEDIA_BASE}/staging/2-remuxed/movies/${SAFE_NAME}"
        JOB_NAME="remux_movie_${SAFE_NAME}"
        DISPLAY_INFO="Movie: $NAME"
        ;;
    show)
        SEASON_DIR=$(printf "S%02d" "$SEASON")
        SEASON_PADDED=$(printf "%02d" "$SEASON")
        INPUT_DIR="${MEDIA_BASE}/staging/1-ripped/tv/${SAFE_NAME}/${SEASON_DIR}"
        OUTPUT_DIR="${MEDIA_BASE}/staging/2-remuxed/tv/${SAFE_NAME}/Season_${SEASON_PADDED}"
        JOB_NAME="remux_tv_${SAFE_NAME}_${SEASON_DIR}"
        DISPLAY_INFO="Show: $NAME | Season: $SEASON"
        ;;
esac

# Verify input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory not found: $INPUT_DIR"
    exit 1
fi

# Check if output directory already exists
if [ -d "$OUTPUT_DIR" ]; then
    echo "Warning: Output directory already exists: $OUTPUT_DIR"
    read -p "Continue and potentially overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Create output directory and state tracking
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/.remux"
mkdir -p "$ACTIVE_JOBS_DIR"

# Initialize state
STATE_DIR="$OUTPUT_DIR/.remux"
echo "in_progress" > "$STATE_DIR/status"
echo "$$" > "$STATE_DIR/pid"
date -Iseconds > "$STATE_DIR/started_at"

# Store job metadata
cat > "$STATE_DIR/metadata.json" << EOF
{
  "type": "$TYPE",
  "name": "$NAME",
  "safe_name": "$SAFE_NAME",
  "season": "$SEASON",
  "input_dir": "$INPUT_DIR",
  "output_dir": "$OUTPUT_DIR",
  "started_at": "$(date -Iseconds)",
  "pid": $$
}
EOF

# Create symlink for global job tracking
ln -sf "$STATE_DIR" "$ACTIVE_JOBS_DIR/$JOB_NAME"

# Set up logging - redirect all output to log file AND stdout
LOG_FILE="$STATE_DIR/remux.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Cleanup function to handle exit (success or failure)
cleanup() {
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "completed" > "$STATE_DIR/status"
        date -Iseconds > "$STATE_DIR/completed_at"
        echo ""
        echo "=========================================="
        echo "✓ Remux completed successfully"
        echo "=========================================="
    else
        echo "failed" > "$STATE_DIR/status"
        echo "Exit code: $exit_code" > "$STATE_DIR/error"
        date -Iseconds > "$STATE_DIR/failed_at"
        echo ""
        echo "=========================================="
        echo "✗ Remux failed with exit code: $exit_code"
        echo "Check: $STATE_DIR/remux.log"
        echo "=========================================="
    fi

    # Remove PID file (process is done)
    rm -f "$STATE_DIR/pid"

    # Remove symlink from active jobs (job is no longer active)
    rm -f "$ACTIVE_JOBS_DIR/$JOB_NAME"
}

# Register cleanup to run on exit
trap cleanup EXIT

echo "=========================================="
echo "Media Remux"
echo "=========================================="
echo "$DISPLAY_INFO"
echo "Input: $INPUT_DIR"
echo "Output: $OUTPUT_DIR"
echo "State: $STATE_DIR"
echo "Log: $LOG_FILE"
echo "PID: $$"
echo "=========================================="
echo ""

# Function to remux and filter tracks
remux_filter_tracks() {
    local input_file="$1"
    local output_file="$2"
    local temp_file="${output_file%.*}_temp.mkv"

    # Get JSON data
    local json_data
    json_data=$(mkvmerge -J "$input_file" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$json_data" ]; then
        echo "  ✗ Error reading file with mkvmerge"
        return 1
    fi

    # Get track IDs for English and Bulgarian
    local audio_tracks
    audio_tracks=$(echo "$json_data" | jq -r '
        [.tracks[] |
         select(.type == "audio" and (.properties.language == "eng" or .properties.language == "bul")) |
         .id] | join(",")')

    local subtitle_tracks
    subtitle_tracks=$(echo "$json_data" | jq -r '
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
    local mkvmerge_output
    mkvmerge_output=$(eval $cmd 2>&1)
    local mkvmerge_exit=$?

    if [ $mkvmerge_exit -eq 0 ] && [ -f "$temp_file" ]; then
        # Calculate space saved
        local orig_size new_size saved_mb percent
        orig_size=$(stat -c%s "$input_file" 2>/dev/null || echo "0")
        new_size=$(stat -c%s "$temp_file" 2>/dev/null || echo "0")

        if [ "$orig_size" -gt 0 ] && [ "$new_size" -gt 0 ]; then
            saved_mb=$(( (orig_size - new_size) / 1024 / 1024 ))
            percent=$((100 - (new_size * 100 / orig_size)))
            mv "$temp_file" "$output_file"
            echo "  ✓ Saved ${saved_mb}MB (${percent}% reduction)"
            return 0
        else
            mv "$temp_file" "$output_file"
            echo "  ✓ Done"
            return 0
        fi
    else
        echo "  ✗ mkvmerge failed (exit code: $mkvmerge_exit)"
        [ -n "$mkvmerge_output" ] && echo "  Error: $(echo "$mkvmerge_output" | head -2)"
        rm -f "$temp_file"
        return 1
    fi
}

# Function to collect extras from a directory (preserving categories)
collect_extras() {
    local extras_base="$1"
    local -n extras_map="$2"

    if [ ! -d "$extras_base" ]; then
        return
    fi

    # Find all category directories
    while IFS= read -r -d '' category_dir; do
        local category
        category=$(basename "$category_dir")

        # Find all MKV files in this category
        while IFS= read -r -d '' extra_file; do
            # Store as "category|file_path"
            if [ -z "${extras_map[$category]}" ]; then
                extras_map[$category]="$extra_file"
            else
                extras_map[$category]="${extras_map[$category]}|$extra_file"
            fi
        done < <(find "$category_dir" -maxdepth 1 -name "*.mkv" -type f -print0 | sort -z)
    done < <(find "$extras_base" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
}

# Variables for tracking
PROCESSED=0
FAILED=0
TOTAL_FILES=0

# Process based on type
if [ "$TYPE" == "show" ]; then
    # TV SHOW PROCESSING
    # Find all disc directories
    mapfile -t DISC_DIRS < <(find "$INPUT_DIR" -maxdepth 1 -type d -name "Disc*" | sort)

    if [ ${#DISC_DIRS[@]} -eq 0 ]; then
        echo "Error: No disc directories found in $INPUT_DIR"
        echo "Expected: Disc1/, Disc2/, etc."
        exit 1
    fi

    echo "Found ${#DISC_DIRS[@]} disc(s):"
    for disc in "${DISC_DIRS[@]}"; do
        disc_name=$(basename "$disc")
        ep_count=$(find "$disc/_episodes" -maxdepth 1 -name "*.mkv" -type f 2>/dev/null | wc -l)
        echo "  - $disc_name: $ep_count episodes"
    done
    echo ""

    # Collect all episodes from all discs
    echo "Scanning episodes from all discs..."
    declare -a ALL_EPISODES
    declare -a EPISODE_SOURCES

    for disc_dir in "${DISC_DIRS[@]}"; do
        disc_name=$(basename "$disc_dir")
        episodes_dir="$disc_dir/_episodes"

        if [ ! -d "$episodes_dir" ]; then
            echo "Warning: No _episodes/ directory in $disc_name, skipping"
            continue
        fi

        # Get episodes sorted by filename (01.mkv, 02.mkv, etc.)
        while IFS= read -r -d '' file; do
            ALL_EPISODES+=("$file")
            EPISODE_SOURCES+=("$disc_name")
        done < <(find "$episodes_dir" -maxdepth 1 -name "*.mkv" -type f -print0 | sort -z)
    done

    TOTAL_EPISODES=${#ALL_EPISODES[@]}

    if [ $TOTAL_EPISODES -eq 0 ]; then
        echo "Error: No episodes found in any disc's _episodes/ directory"
        exit 1
    fi

    echo "Found $TOTAL_EPISODES total episodes"
    echo ""

    # Display episode mapping
    echo "Episode mapping:"
    for i in "${!ALL_EPISODES[@]}"; do
        ep_num=$((i + 1))
        src_file=$(basename "${ALL_EPISODES[$i]}")
        src_disc="${EPISODE_SOURCES[$i]}"
        printf "  S%02dE%02d ← %s [%s]\n" "$SEASON" "$ep_num" "$src_file" "$src_disc"
    done
    echo ""

    # Collect all extras from all discs
    echo "Scanning extras from all discs..."
    declare -A EXTRAS_BY_CATEGORY

    for disc_dir in "${DISC_DIRS[@]}"; do
        collect_extras "$disc_dir/_extras" EXTRAS_BY_CATEGORY
    done

    TOTAL_EXTRAS=0
    for category in "${!EXTRAS_BY_CATEGORY[@]}"; do
        IFS='|' read -ra files <<< "${EXTRAS_BY_CATEGORY[$category]}"
        TOTAL_EXTRAS=$((TOTAL_EXTRAS + ${#files[@]}))
        echo "  $category/: ${#files[@]} file(s)"
    done

    if [ $TOTAL_EXTRAS -eq 0 ]; then
        echo "  (no extras found)"
    fi
    echo ""

    TOTAL_FILES=$((TOTAL_EPISODES + TOTAL_EXTRAS))

    # Process episodes
    echo "=========================================="
    echo "Remuxing Episodes"
    echo "=========================================="
    echo "Keeping: English and Bulgarian audio/subtitles"
    echo "Removing: All other language tracks"
    echo ""

    for i in "${!ALL_EPISODES[@]}"; do
        ep_num=$((i + 1))
        input_file="${ALL_EPISODES[$i]}"
        output_file=$(printf "%s/S%02dE%02d.mkv" "$OUTPUT_DIR" "$SEASON" "$ep_num")

        printf "[%d/%d] S%02dE%02d ← %s\n" "$((i + 1))" "$TOTAL_FILES" "$SEASON" "$ep_num" "$(basename "$input_file")"

        if remux_filter_tracks "$input_file" "$output_file"; then
            PROCESSED=$((PROCESSED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done

    echo ""

else
    # MOVIE PROCESSING
    echo "Scanning movie directory..."

    # Find main feature
    MAIN_DIR="$INPUT_DIR/_main"
    if [ ! -d "$MAIN_DIR" ]; then
        echo "Error: No _main/ directory found in $INPUT_DIR"
        echo "Please organize the main feature into _main/"
        exit 1
    fi

    mapfile -t MAIN_FILES < <(find "$MAIN_DIR" -maxdepth 1 -name "*.mkv" -type f | sort)

    if [ ${#MAIN_FILES[@]} -eq 0 ]; then
        echo "Error: No MKV files found in _main/"
        exit 1
    fi

    if [ ${#MAIN_FILES[@]} -gt 1 ]; then
        echo "Warning: Multiple files in _main/, using first one:"
        for f in "${MAIN_FILES[@]}"; do
            echo "  - $(basename "$f")"
        done
    fi

    MAIN_FILE="${MAIN_FILES[0]}"
    echo "Main feature: $(basename "$MAIN_FILE")"
    echo ""

    # Collect extras
    echo "Scanning extras..."
    declare -A EXTRAS_BY_CATEGORY
    collect_extras "$INPUT_DIR/_extras" EXTRAS_BY_CATEGORY

    TOTAL_EXTRAS=0
    for category in "${!EXTRAS_BY_CATEGORY[@]}"; do
        IFS='|' read -ra files <<< "${EXTRAS_BY_CATEGORY[$category]}"
        TOTAL_EXTRAS=$((TOTAL_EXTRAS + ${#files[@]}))
        echo "  $category/: ${#files[@]} file(s)"
    done

    if [ $TOTAL_EXTRAS -eq 0 ]; then
        echo "  (no extras found)"
    fi
    echo ""

    TOTAL_FILES=$((1 + TOTAL_EXTRAS))

    # Process main feature
    echo "=========================================="
    echo "Remuxing Main Feature"
    echo "=========================================="
    echo "Keeping: English and Bulgarian audio/subtitles"
    echo "Removing: All other language tracks"
    echo ""

    output_file="$OUTPUT_DIR/${SAFE_NAME}.mkv"
    printf "[1/%d] %s\n" "$TOTAL_FILES" "$(basename "$MAIN_FILE")"

    if remux_filter_tracks "$MAIN_FILE" "$output_file"; then
        PROCESSED=$((PROCESSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi

    echo ""
fi

# Process extras (common for both types)
if [ ${#EXTRAS_BY_CATEGORY[@]} -gt 0 ] && [ $TOTAL_EXTRAS -gt 0 ]; then
    echo "=========================================="
    echo "Remuxing Extras (preserving categories)"
    echo "=========================================="
    echo ""

    EXTRA_COUNT=$((PROCESSED + FAILED))
    for category in "${!EXTRAS_BY_CATEGORY[@]}"; do
        echo "Processing $category/..."
        mkdir -p "$OUTPUT_DIR/$category"

        IFS='|' read -ra files <<< "${EXTRAS_BY_CATEGORY[$category]}"
        for extra_file in "${files[@]}"; do
            EXTRA_COUNT=$((EXTRA_COUNT + 1))
            filename=$(basename "$extra_file")
            output_file="$OUTPUT_DIR/$category/$filename"

            printf "  [%d/%d] %s\n" "$EXTRA_COUNT" "$TOTAL_FILES" "$filename"
            if remux_filter_tracks "$extra_file" "$output_file"; then
                PROCESSED=$((PROCESSED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
        done
        echo ""
    done
fi

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Results:"
echo "  - Successfully processed: $PROCESSED files"
if [ $FAILED -gt 0 ]; then
    echo "  - Failed: $FAILED files"
fi
echo ""

# Count output files
if [ "$TYPE" == "show" ]; then
    CREATED_MAIN=$(find "$OUTPUT_DIR" -maxdepth 1 -name "S*.mkv" -type f | wc -l)
    echo "Created:"
    echo "  - $CREATED_MAIN episodes"
else
    CREATED_MAIN=$(find "$OUTPUT_DIR" -maxdepth 1 -name "*.mkv" -type f | wc -l)
    echo "Created:"
    echo "  - $CREATED_MAIN main feature(s)"
fi

for category in "${!EXTRAS_BY_CATEGORY[@]}"; do
    count=$(find "$OUTPUT_DIR/$category" -name "*.mkv" -type f 2>/dev/null | wc -l)
    if [ $count -gt 0 ]; then
        echo "  - $count extras in $category/"
    fi
done

echo ""
echo "Next steps:"
echo "  1. Review output in Jellyfin 'Staging - Remuxed' library"
echo "  2. Transcode: ./transcode-queue.sh \"$OUTPUT_DIR\" 20 software --auto"
if [ "$TYPE" == "show" ]; then
    echo "  3. FileBot for final naming: ./filebot-process.sh \"$OUTPUT_DIR\""
else
    echo "  3. FileBot for final naming: ./filebot-process.sh \"$OUTPUT_DIR\""
fi
echo ""
