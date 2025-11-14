#!/bin/bash
# transcode-queue.sh - Queue-based batch transcoding
#
# Usage: ./transcode-queue.sh <folder> [CRF] [MODE] [--auto]
#
# MODE: software (default) or hardware
# CRF: 18-22 (default: 20)
# --auto: Skip confirmation prompt (for nohup usage)
#
# Supports new directory structure:
#   - Reads from: /mnt/staging/2-remuxed/...
#   - Writes to:  /mnt/staging/3-transcoded/... (mirrors structure)
#   - Or legacy: creates *_transcoded.mkv in same folder

# Auto-detect staging base path
# In CT304 (transcoder), storage is mounted at /mnt/staging
# On host or other containers, it may be /mnt/storage/media/staging
if [ -d "/mnt/staging/1-ripped" ]; then
    STAGING_BASE="${STAGING_BASE:-/mnt/staging}"
else
    STAGING_BASE="${STAGING_BASE:-/mnt/storage/media/staging}"
fi

FOLDER="$1"
CRF="${2:-20}"
MODE="${3:-software}"
AUTO_MODE=0

# Check for --auto flag in any position
for arg in "$@"; do
    if [ "$arg" = "--auto" ]; then
        AUTO_MODE=1
    fi
done

if [ -z "$FOLDER" ]; then
    echo "Usage: $0 <folder> [CRF] [MODE] [--auto]"
    echo ""
    echo "Examples:"
    echo "  $0 /mnt/staging/2-remuxed/movies/Movie_2024-11-10/ 20 software"
    echo "  $0 /mnt/staging/2-remuxed/tv/Show/Season_01/ 20 software"
    echo "  $0 /mnt/staging/2-remuxed/movies/Movie/ 20 hardware --auto"
    echo ""
    echo "Or use relative paths (requires STAGING_BASE env var):"
    echo "  $0 2-remuxed/movies/Movie/ 20 software"
    echo ""
    echo "Current STAGING_BASE: $STAGING_BASE"
    exit 1
fi

# Handle relative paths (resolve with STAGING_BASE)
if [[ ! "$FOLDER" =~ ^/ ]]; then
    # Relative path - prepend STAGING_BASE
    FOLDER="$STAGING_BASE/$FOLDER"
    echo "Resolved relative path to: $FOLDER"
    echo ""
fi

if [ ! -d "$FOLDER" ]; then
    echo "Error: Directory not found: $FOLDER"
    echo ""
    echo "Hint: Make sure STAGING_BASE is set correctly."
    echo "Current STAGING_BASE: $STAGING_BASE"
    exit 1
fi

# Validate mode
if [[ ! "$MODE" =~ ^(software|hardware)$ ]]; then
    echo "Error: Mode must be 'software' or 'hardware'"
    exit 1
fi

# Detect if using new structure (2-remuxed -> 3-transcoded)
if [[ "$FOLDER" =~ /2-remuxed/ ]]; then
    NEW_STRUCTURE=1
    OUTPUT_BASE="${FOLDER/\/2-remuxed\//\/3-transcoded\/}"
    echo "Using new directory structure:"
    echo "  Input:  $FOLDER"
    echo "  Output: $OUTPUT_BASE"
else
    NEW_STRUCTURE=0
    OUTPUT_BASE="$FOLDER"
    echo "Using legacy structure (output in same folder with _transcoded suffix)"
fi
echo ""

# Create queue directory
QUEUE_DIR="$FOLDER/.transcode_queue"
mkdir -p "$QUEUE_DIR"

QUEUE_FILE="$QUEUE_DIR/queue.txt"
COMPLETED_FILE="$QUEUE_DIR/completed.txt"
FAILED_FILE="$QUEUE_DIR/failed.txt"
LOG_DIR="$QUEUE_DIR/logs"
mkdir -p "$LOG_DIR"

# Initialize queue if it doesn't exist
if [ ! -f "$QUEUE_FILE" ]; then
    echo "Building queue..."
    
    # Find all MKV files including in extras/ subfolders
    # Store as: input_path|output_path
    while IFS= read -r -d '' file; do
        # Calculate relative path from input folder
        rel_path="${file#$FOLDER/}"
        
        # Safety check: if rel_path starts with /, the strip failed (path mismatch)
        if [[ "$rel_path" == /* ]]; then
            echo "ERROR: Path mismatch detected!"
            echo "  FOLDER=$FOLDER"
            echo "  File found=$file"
            echo "  The file path doesn't start with FOLDER path."
            echo "  This usually means STAGING_BASE is incorrect for this container."
            rm -f "$QUEUE_FILE"
            exit 1
        fi
        
        # Determine output path
        if [ $NEW_STRUCTURE -eq 1 ]; then
            # New structure: mirror to 3-transcoded
            output_file="$OUTPUT_BASE/$rel_path"
        else
            # Legacy: add _transcoded suffix
            output_file="${file%.*}_transcoded.mkv"
        fi
        
        # Store mapping
        echo "$file|$output_file" >> "$QUEUE_FILE"
    done < <(find "$FOLDER" -name "*.mkv" ! -name "*_transcoded.mkv" -type f -print0 | sort -z)
    
    total=$(wc -l < "$QUEUE_FILE")
    echo "Added $total file(s) to queue"
    echo ""
fi

# Initialize completed/failed lists
touch "$COMPLETED_FILE"
touch "$FAILED_FILE"

# Show queue status
total=$(wc -l < "$QUEUE_FILE" || echo 0)
completed=$(wc -l < "$COMPLETED_FILE" || echo 0)
failed=$(wc -l < "$FAILED_FILE" || echo 0)
remaining=$((total - completed - failed))

echo "=================================================="
echo "Transcode Queue - $MODE Encoding"
echo "=================================================="
echo "Folder: $FOLDER"
echo "CRF: $CRF"
echo "Mode: $MODE"
echo ""
echo "Queue Status:"
echo "  Total:     $total"
echo "  Completed: $completed"
echo "  Failed:    $failed"
echo "  Remaining: $remaining"
echo "=================================================="
echo ""

if [ $remaining -eq 0 ]; then
    echo "✓ Queue is empty! All files processed."
    exit 0
fi

# Skip confirmation if --auto flag set
if [ $AUTO_MODE -eq 0 ]; then
    read -p "Start processing $remaining file(s)? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
else
    echo "Auto mode: Starting processing of $remaining file(s)..."
fi

echo ""
echo "Starting batch transcode..."
echo "Logs saved to: $LOG_DIR"
echo ""

# Process queue
current=0
while IFS='|' read -r input_file output_file; do
    # Skip if already completed or failed
    if grep -Fxq "$input_file" "$COMPLETED_FILE" 2>/dev/null; then
        continue
    fi
    if grep -Fxq "$input_file" "$FAILED_FILE" 2>/dev/null; then
        continue
    fi
    
    current=$((current + 1))
    filename=$(basename "$input_file")
    
    # Create output directory if needed (for new structure)
    output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    log_file="$LOG_DIR/$(date +%Y%m%d_%H%M%S)_${filename}.log"
    
    echo "=================================================="
    echo "[$current/$remaining] Processing: $filename"
    echo "=================================================="
    echo "Started: $(date)"
    echo "Log: $log_file"
    echo ""
    
    # Start time
    start_time=$(date +%s)
    
    # Build ffmpeg command based on mode
    if [ "$MODE" = "hardware" ]; then
        ffmpeg_cmd="ffmpeg -nostdin -hwaccel qsv -hwaccel_output_format qsv -i \"$input_file\" -c:v hevc_qsv -preset medium -global_quality $CRF -c:a copy -c:s copy -y \"$output_file\""
    else
        ffmpeg_cmd="ffmpeg -nostdin -i \"$input_file\" -map 0:v:0 -map 0:a -map 0:s? -c:v libx265 -preset slow -crf $CRF -c:a copy -c:s copy -y \"$output_file\""
    fi
    
    # Execute
    eval $ffmpeg_cmd > "$log_file" 2>&1
    exit_code=$?
    
    # Calculate elapsed time
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    elapsed_min=$((elapsed / 60))
    
    if [ $exit_code -eq 0 ] && [ -f "$output_file" ]; then
        # Get sizes
        input_size=$(du -h "$input_file" | cut -f1)
        output_size=$(du -h "$output_file" | cut -f1)
        input_bytes=$(stat -c%s "$input_file" 2>/dev/null || stat -f%z "$input_file")
        output_bytes=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file")
        saved_gb=$(awk "BEGIN {printf \"%.2f\", ($input_bytes - $output_bytes)/1024/1024/1024}")
        percent=$(awk "BEGIN {printf \"%.1f\", 100 - ($output_bytes * 100 / $input_bytes)}")
        
        echo "✓ Success!"
        echo "  Input:  $input_size → Output: $output_size"
        echo "  Saved:  ${saved_gb}GB (${percent}% reduction)"
        echo "  Time:   ${elapsed_min} minutes"
        echo "  Output: $output_file"
        echo ""
        
        # Mark as completed
        echo "$input_file" >> "$COMPLETED_FILE"
    else
        echo "✗ Failed! (exit code: $exit_code)"
        echo "  Check log: $log_file"
        echo ""
        
        # Mark as failed
        echo "$input_file" >> "$FAILED_FILE"
        
        # Clean up partial output
        rm -f "$output_file"
    fi
    
    echo "Finished: $(date)"
    echo ""
done < "$QUEUE_FILE"

# Final summary
echo "=================================================="
echo "Batch Transcode Complete"
echo "=================================================="
completed_final=$(wc -l < "$COMPLETED_FILE")
failed_final=$(wc -l < "$FAILED_FILE")

echo "Completed: $completed_final"
echo "Failed:    $failed_final"
echo ""

if [ $failed_final -gt 0 ]; then
    echo "Failed files:"
    cat "$FAILED_FILE"
    echo ""
fi

echo "All logs saved to: $LOG_DIR"
echo ""
echo "⚠️  Remember to verify transcoded files before deleting originals!"
echo ""
