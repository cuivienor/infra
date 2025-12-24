#!/bin/bash
# Media Transcoder
# Usage: ./transcode.sh -t <type> -n <name> [-s <season>] [-c <crf>] [-m <mode>]
#
# Examples:
#   ./transcode.sh -t movie -n "The Lion King"
#   ./transcode.sh -t show -n "Avatar The Last Airbender" -s 2
#   ./transcode.sh -t show -n "Breaking Bad" -s 3 -c 18 -m hardware
#
# State Management:
#   - Creates .transcode/ directory with status, logs, and metadata
#   - Creates symlink in ~/active-jobs/ for global visibility
#   - Status: in_progress → completed or failed
#   - Supports resume: skips already completed files
#
# Monitoring:
#   ls ~/active-jobs/                          # See all active jobs
#   cat ~/active-jobs/*/status                 # Check status
#   tail -f ~/active-jobs/*/transcode.log     # Follow logs

set -e

# Default values
TYPE=""
NAME=""
SEASON=""
CRF="20"
MODE="software"

# Global state directory for active jobs
ACTIVE_JOBS_DIR="$HOME/active-jobs"

# Standardized media path
MEDIA_BASE="/mnt/media"

# Help function
show_help() {
    cat << EOF
Usage: $0 -t <type> -n <name> [-s <season>] [-c <crf>] [-m <mode>]

Options:
  -t, --type <type>       Media type: 'movie' or 'show' (required)
  -n, --name <name>       Title of the movie or show (required)
  -s, --season <number>   Season number (required for shows)
  -c, --crf <number>      Quality (18-28, default: 20, lower=better)
  -m, --mode <mode>       Encoding: 'software' or 'hardware' (default: software)
  -h, --help              Show this help message

Examples:
  $0 -t movie -n "The Lion King"
  $0 -t show -n "Avatar The Last Airbender" -s 2
  $0 --type show --name "Breaking Bad" --season 3 --crf 18 --mode hardware

State Management:
  Job state is tracked in OUTPUT_DIR/.transcode/
  Active jobs are symlinked in ~/active-jobs/
  Supports resume: Re-run to continue after interruption

Monitoring:
  ls ~/active-jobs/                          # See all active jobs
  cat ~/active-jobs/*/status                 # Check status
  tail -f ~/active-jobs/*/transcode.log     # Follow logs
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
        -c|--crf)
            CRF="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
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

# Validate mode
if [[ ! "$MODE" =~ ^(software|hardware)$ ]]; then
    echo "Error: Mode must be 'software' or 'hardware'"
    exit 1
fi

# Validate CRF
if ! [[ "$CRF" =~ ^[0-9]+$ ]] || [ "$CRF" -lt 0 ] || [ "$CRF" -gt 51 ]; then
    echo "Error: CRF must be a number between 0-51"
    exit 1
fi

# Require season for shows
if [[ "$TYPE" == "show" ]]; then
    if [ -z "$SEASON" ]; then
        echo "Error: --season is required for TV shows"
        echo "Example: $0 -t show -n \"$NAME\" -s 1"
        exit 1
    fi

    if ! [[ "$SEASON" =~ ^[0-9]+$ ]]; then
        echo "Error: Season must be a number"
        exit 1
    fi
fi

# Create safe directory names
SAFE_NAME=$(echo "$NAME" | tr ' ' '_' | tr -cd '[:alnum:]_-')

# Verify mount exists
if [ ! -d "$MEDIA_BASE/staging" ]; then
    echo "Error: Media mount not found at $MEDIA_BASE/staging"
    echo "Expected mount: $MEDIA_BASE → /mnt/storage/media"
    exit 1
fi

# Set paths based on type
case "$TYPE" in
    movie)
        INPUT_DIR="${MEDIA_BASE}/staging/2-remuxed/movies/${SAFE_NAME}"
        OUTPUT_DIR="${MEDIA_BASE}/staging/3-transcoded/movies/${SAFE_NAME}"
        DISPLAY_INFO="Movie: $NAME"
        JOB_NAME="transcode_movie_${SAFE_NAME}"
        ;;
    show)
        SEASON_DIR=$(printf "Season_%02d" "$SEASON")
        INPUT_DIR="${MEDIA_BASE}/staging/2-remuxed/tv/${SAFE_NAME}/${SEASON_DIR}"
        OUTPUT_DIR="${MEDIA_BASE}/staging/3-transcoded/tv/${SAFE_NAME}/${SEASON_DIR}"
        DISPLAY_INFO="Show: $NAME | Season: $SEASON"
        JOB_NAME="transcode_tv_${SAFE_NAME}_S$(printf "%02d" "$SEASON")"
        ;;
esac

# Verify input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory not found: $INPUT_DIR"
    exit 1
fi

# Check if output directory already exists
if [ -d "$OUTPUT_DIR" ]; then
    echo "Note: Output directory already exists: $OUTPUT_DIR"
    echo "Will resume from previous state (completed files will be skipped)"
    echo ""
fi

# Create output directory and state tracking
mkdir -p "$OUTPUT_DIR"

STATE_DIR="$OUTPUT_DIR/.transcode"
mkdir -p "$STATE_DIR"

LOG_FILE="$STATE_DIR/transcode.log"
QUEUE_FILE="$STATE_DIR/queue.txt"
COMPLETED_FILE="$STATE_DIR/completed.txt"
FAILED_FILE="$STATE_DIR/failed.txt"
STATUS_FILE="$STATE_DIR/status"
METADATA_FILE="$STATE_DIR/metadata.json"
PID_FILE="$STATE_DIR/pid"
STARTED_FILE="$STATE_DIR/started_at"
COMPLETED_AT_FILE="$STATE_DIR/completed_at"

# Create global active-jobs directory
mkdir -p "$ACTIVE_JOBS_DIR"

# Create symlink for global visibility
ln -sfn "$STATE_DIR" "$ACTIVE_JOBS_DIR/$JOB_NAME"

# Track current ffmpeg PID for cleanup on interrupt
CURRENT_FFMPEG_PID=""

cleanup() {
    if [ -n "$CURRENT_FFMPEG_PID" ] && kill -0 "$CURRENT_FFMPEG_PID" 2>/dev/null; then
        echo ""
        echo "Interrupted! Stopping ffmpeg (PID: $CURRENT_FFMPEG_PID)..."
        kill "$CURRENT_FFMPEG_PID" 2>/dev/null
        wait "$CURRENT_FFMPEG_PID" 2>/dev/null
    fi

    # Mark as failed on interrupt
    echo "failed" > "$STATUS_FILE"

    # Clean up PID file and symlink
    rm -f "$PID_FILE"
    rm -f "$ACTIVE_JOBS_DIR/$JOB_NAME"

    exit 130
}

trap cleanup INT TERM

# Initialize state
echo "in_progress" > "$STATUS_FILE"
echo "$$" > "$PID_FILE"
date -Iseconds > "$STARTED_FILE"

# Save metadata
cat > "$METADATA_FILE" << EOF
{
  "type": "$TYPE",
  "name": "$NAME",
  "safe_name": "$SAFE_NAME",
  "season": "$SEASON",
  "crf": "$CRF",
  "mode": "$MODE",
  "input_dir": "$INPUT_DIR",
  "output_dir": "$OUTPUT_DIR",
  "started_at": "$(cat "$STARTED_FILE")",
  "pid": $$
}
EOF

# Start logging (tee to both file and stdout)
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "$DISPLAY_INFO"
echo "=========================================="
echo "Input: $INPUT_DIR"
echo "Output: $OUTPUT_DIR"
echo "CRF: $CRF"
echo "Mode: $MODE"
echo "State: $STATE_DIR"
echo "Log: $LOG_FILE"
echo "PID: $$"
echo "=========================================="
echo ""

# Build queue if it doesn't exist or is empty
if [ ! -f "$QUEUE_FILE" ] || [ ! -s "$QUEUE_FILE" ]; then
    echo "Building transcode queue..."

    # Find all MKV files, excluding .remux and .transcode directories
    : > "$QUEUE_FILE"  # Clear/create queue file

    while IFS= read -r -d '' file; do
        # Calculate relative path from input folder
        rel_path="${file#$INPUT_DIR/}"

        # Determine output path (mirror structure)
        output_file="$OUTPUT_DIR/$rel_path"

        # Store mapping: input|output|relative_path
        echo "$file|$output_file|$rel_path" >> "$QUEUE_FILE"
    done < <(find "$INPUT_DIR" -name "*.mkv" -type f ! -path "*/.remux/*" ! -path "*/.transcode/*" -print0 | sort -z)

    total=$(wc -l < "$QUEUE_FILE")
    echo "Added $total file(s) to queue"
else
    echo "Using existing queue (resuming)"
    total=$(wc -l < "$QUEUE_FILE")
fi
echo ""

# Initialize completed/failed lists if they don't exist
touch "$COMPLETED_FILE"
touch "$FAILED_FILE"

# Show queue status
completed_count=$(wc -l < "$COMPLETED_FILE" 2>/dev/null || echo 0)
failed_count=$(wc -l < "$FAILED_FILE" 2>/dev/null || echo 0)
remaining=$((total - completed_count - failed_count))

echo "Queue Status:"
echo "  Total:     $total"
echo "  Completed: $completed_count"
echo "  Failed:    $failed_count"
echo "  Remaining: $remaining"
echo ""

if [ $remaining -eq 0 ]; then
    echo "All files already processed!"
    echo "completed" > "$STATUS_FILE"
    date -Iseconds > "$COMPLETED_AT_FILE"
    rm -f "$PID_FILE"
    rm -f "$ACTIVE_JOBS_DIR/$JOB_NAME"
    exit 0
fi

echo "Starting transcode of $remaining file(s)..."
echo ""

# Process queue
current=0
success_count=0
fail_count=0

while IFS='|' read -r input_file output_file rel_path; do
    # Skip if already completed
    if grep -Fxq "$rel_path" "$COMPLETED_FILE" 2>/dev/null; then
        continue
    fi

    # Skip if already marked as failed (can retry by removing from failed.txt)
    if grep -Fxq "$rel_path" "$FAILED_FILE" 2>/dev/null; then
        continue
    fi

    current=$((current + 1))

    # Create output directory if needed (for extras subdirectories)
    output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"

    echo "=========================================="
    echo "[$current/$remaining] $rel_path"
    echo "=========================================="
    echo "Started: $(date)"

    # Start time
    start_time=$(date +%s)

    # Build ffmpeg command based on mode
    if [ "$MODE" = "hardware" ]; then
        # Intel QSV hardware encoding
        ffmpeg_cmd=(ffmpeg -nostdin -hwaccel qsv -hwaccel_output_format qsv
            -i "$input_file"
            -c:v hevc_qsv -preset medium -global_quality "$CRF"
            -c:a copy -c:s copy
            -y "$output_file")
    else
        # Software encoding (libx265)
        ffmpeg_cmd=(ffmpeg -nostdin
            -i "$input_file"
            -map 0:v:0 -map 0:a -map 0:s?
            -c:v libx265 -preset slow -crf "$CRF"
            -c:a copy -c:s copy
            -y "$output_file")
    fi

    # Execute ffmpeg (capture output to show progress)
    "${ffmpeg_cmd[@]}" 2>&1 | tail -20 &
    CURRENT_FFMPEG_PID=$!
    wait "$CURRENT_FFMPEG_PID"
    exit_code=$?
    CURRENT_FFMPEG_PID=""

    # Calculate elapsed time
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    elapsed_min=$((elapsed / 60))
    elapsed_sec=$((elapsed % 60))

    if [ $exit_code -eq 0 ] && [ -f "$output_file" ]; then
        # Get sizes
        input_bytes=$(stat -c%s "$input_file" 2>/dev/null || echo "0")
        output_bytes=$(stat -c%s "$output_file" 2>/dev/null || echo "0")

        if [ "$input_bytes" -gt 0 ]; then
            saved_mb=$(( (input_bytes - output_bytes) / 1024 / 1024 ))
            saved_gb=$(awk "BEGIN {printf \"%.2f\", $saved_mb/1024}")
            percent=$(awk "BEGIN {printf \"%.1f\", 100 - ($output_bytes * 100 / $input_bytes)}")

            input_size=$(awk "BEGIN {printf \"%.2fGB\", $input_bytes/1024/1024/1024}")
            output_size=$(awk "BEGIN {printf \"%.2fGB\", $output_bytes/1024/1024/1024}")

            echo "  ✓ Success!"
            echo "  Size: $input_size → $output_size (${percent}% reduction, saved ${saved_gb}GB)"
        else
            echo "  ✓ Success!"
        fi

        echo "  Time: ${elapsed_min}m ${elapsed_sec}s"

        # Mark as completed
        echo "$rel_path" >> "$COMPLETED_FILE"
        success_count=$((success_count + 1))
    else
        echo "  ✗ Failed! (exit code: $exit_code)"

        # Mark as failed
        echo "$rel_path" >> "$FAILED_FILE"
        fail_count=$((fail_count + 1))

        # Clean up partial output
        rm -f "$output_file"
    fi

    echo ""
done < "$QUEUE_FILE"

# Final summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Results:"
echo "  - Successfully transcoded: $success_count files"
if [ $fail_count -gt 0 ]; then
    echo "  - Failed: $fail_count files"
    echo ""
    echo "Failed files:"
    cat "$FAILED_FILE"
fi
echo ""

# Calculate total size savings
total_input_size=0
total_output_size=0

while IFS='|' read -r input_file output_file rel_path; do
    if grep -Fxq "$rel_path" "$COMPLETED_FILE" 2>/dev/null; then
        if [ -f "$output_file" ]; then
            input_bytes=$(stat -c%s "$input_file" 2>/dev/null || echo "0")
            output_bytes=$(stat -c%s "$output_file" 2>/dev/null || echo "0")
            total_input_size=$((total_input_size + input_bytes))
            total_output_size=$((total_output_size + output_bytes))
        fi
    fi
done < "$QUEUE_FILE"

if [ $total_input_size -gt 0 ]; then
    total_saved_gb=$(awk "BEGIN {printf \"%.2f\", ($total_input_size - $total_output_size)/1024/1024/1024}")
    total_percent=$(awk "BEGIN {printf \"%.1f\", 100 - ($total_output_size * 100 / $total_input_size)}")
    input_total_gb=$(awk "BEGIN {printf \"%.2f\", $total_input_size/1024/1024/1024}")
    output_total_gb=$(awk "BEGIN {printf \"%.2f\", $total_output_size/1024/1024/1024}")

    echo "Total Size:"
    echo "  - Input:  ${input_total_gb}GB"
    echo "  - Output: ${output_total_gb}GB"
    echo "  - Saved:  ${total_saved_gb}GB (${total_percent}% reduction)"
    echo ""
fi

echo "Next steps:"
echo "  1. Review output quality before deleting originals"
echo "  2. FileBot for final naming: ./filebot-process.sh \"$OUTPUT_DIR\""
echo ""

# Update final state
if [ $fail_count -eq 0 ]; then
    echo "completed" > "$STATUS_FILE"
    echo ""
    echo "=========================================="
    echo "✓ Transcode completed successfully"
    echo "=========================================="
else
    echo "failed" > "$STATUS_FILE"
    echo ""
    echo "=========================================="
    echo "✗ Transcode completed with errors"
    echo "=========================================="
fi

date -Iseconds > "$COMPLETED_AT_FILE"

# Clean up PID file and symlink
rm -f "$PID_FILE"
rm -f "$ACTIVE_JOBS_DIR/$JOB_NAME"
