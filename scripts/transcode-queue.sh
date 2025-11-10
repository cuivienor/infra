#!/bin/bash
# transcode-queue.sh - Queue-based batch transcoding
#
# Usage: ./transcode-queue.sh <folder> [CRF] [MODE] [--auto]
#
# MODE: software (default) or hardware
# CRF: 18-22 (default: 20)
# --auto: Skip confirmation prompt (for nohup usage)

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
    echo "Usage: $0 <folder> [CRF] [MODE]"
    echo ""
    echo "Examples:"
    echo "  $0 /mnt/storage/media/staging/Dragon 20 software"
    echo "  $0 /mnt/storage/media/staging/Dragon 22 hardware"
    exit 1
fi

if [ ! -d "$FOLDER" ]; then
    echo "Error: Directory not found: $FOLDER"
    exit 1
fi

# Validate mode
if [[ ! "$MODE" =~ ^(software|hardware)$ ]]; then
    echo "Error: Mode must be 'software' or 'hardware'"
    exit 1
fi

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
    find "$FOLDER" -maxdepth 1 -name "*.mkv" ! -name "*_transcoded.mkv" -type f > "$QUEUE_FILE"
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
while IFS= read -r file; do
    # Skip if already completed or failed
    if grep -Fxq "$file" "$COMPLETED_FILE" 2>/dev/null; then
        continue
    fi
    if grep -Fxq "$file" "$FAILED_FILE" 2>/dev/null; then
        continue
    fi
    
    current=$((current + 1))
    filename=$(basename "$file")
    output_file="${file%.*}_transcoded.mkv"
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
        ffmpeg_cmd="ffmpeg -hwaccel qsv -hwaccel_output_format qsv -i \"$file\" -c:v hevc_qsv -preset medium -global_quality $CRF -c:a copy -c:s copy -y \"$output_file\""
    else
        ffmpeg_cmd="ffmpeg -i \"$file\" -map 0:v:0 -map 0:a -map 0:s? -c:v libx265 -preset slow -crf $CRF -c:a copy -c:s copy -y \"$output_file\""
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
        input_size=$(du -h "$file" | cut -f1)
        output_size=$(du -h "$output_file" | cut -f1)
        input_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")
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
        echo "$file" >> "$COMPLETED_FILE"
    else
        echo "✗ Failed! (exit code: $exit_code)"
        echo "  Check log: $log_file"
        echo ""
        
        # Mark as failed
        echo "$file" >> "$FAILED_FILE"
        
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
