#!/bin/bash
# transcode-media.sh - Transcode media files to archival quality x265
#
# Usage: ./transcode-media.sh "/path/to/file.mkv" [CRF]
#        ./transcode-media.sh "/path/to/folder/" [CRF]
#
# CRF values: 18 (highest quality), 20 (excellent), 22 (very good)
# Default: 20

INPUT="$1"
CRF="${2:-20}"  # Default CRF 20

if [ -z "$INPUT" ]; then
    echo "Usage: $0 <file.mkv or folder> [CRF]"
    echo ""
    echo "CRF Quality Guide:"
    echo "  18 - Archival (near-transparent, largest files)"
    echo "  20 - Excellent (recommended, ~40-50% of original)"
    echo "  22 - Very good (smaller files, minor quality loss)"
    echo ""
    echo "Examples:"
    echo "  $0 'movie.mkv' 20"
    echo "  $0 /mnt/storage/media/staging/Dragon/ 20"
    exit 1
fi

if [ ! -e "$INPUT" ]; then
    echo "Error: Input does not exist: $INPUT"
    exit 1
fi

# Validate CRF
if [ "$CRF" -lt 16 ] || [ "$CRF" -gt 28 ]; then
    echo "Error: CRF must be between 16-28 (recommended: 18-22)"
    exit 1
fi

# Check ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg not installed"
    exit 1
fi

echo "=================================================="
echo "Media Transcoding - Archival Quality"
echo "=================================================="
echo "Input: $INPUT"
echo "CRF: $CRF (lower = better quality)"
echo "Codec: libx265 (HEVC)"
echo "Preset: slow (best compression)"
echo "Audio: Copy all (no re-encoding)"
echo "Subtitles: Copy all (no re-encoding)"
echo "=================================================="
echo ""

# Function to transcode a single file
transcode_file() {
    local input_file="$1"
    local output_file="${input_file%.*}_transcoded.mkv"
    local temp_file="${input_file%.*}_temp.mkv"
    
    echo ""
    echo "=========================================="
    echo "Transcoding: $(basename "$input_file")"
    echo "=========================================="
    
    # Get input file size
    local input_size=$(du -h "$input_file" | cut -f1)
    echo "Input size: $input_size"
    echo ""
    
    # Get duration for progress estimation
    local duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null)
    local duration_min=$(awk "BEGIN {printf \"%.0f\", $duration/60}")
    echo "Duration: ${duration_min} minutes"
    echo ""
    
    # Estimate time (rough: 1 minute of video = 5-15 minutes encoding on CPU)
    local est_time_hours=$(awk "BEGIN {printf \"%.1f\", $duration_min * 10 / 60}")
    echo "Estimated time: ~${est_time_hours} hours (will vary based on CPU)"
    echo ""
    
    echo "Starting transcode..."
    echo "Press Ctrl+C to cancel (progress will be lost)"
    echo ""
    
    # Start time
    local start_time=$(date +%s)
    
    # Transcode with progress
    ffmpeg -i "$input_file" \
        -map 0:v:0 \
        -map 0:a \
        -map 0:s? \
        -c:v libx265 \
        -preset slow \
        -crf "$CRF" \
        -c:a copy \
        -c:s copy \
        -y \
        "$temp_file" 2>&1 | while read line; do
            # Show progress lines
            if echo "$line" | grep -q "frame="; then
                echo -ne "\r$line"
            elif echo "$line" | grep -qE "(error|Error|failed|Failed)"; then
                echo "$line"
            fi
        done
    
    local exit_code=${PIPESTATUS[0]}
    echo ""  # New line after progress
    
    if [ $exit_code -eq 0 ] && [ -f "$temp_file" ]; then
        # Get output file size
        local output_size=$(du -h "$temp_file" | cut -f1)
        local input_bytes=$(stat -c%s "$input_file" 2>/dev/null || stat -f%z "$input_file")
        local output_bytes=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file")
        
        # Calculate savings
        local saved_bytes=$((input_bytes - output_bytes))
        local saved_gb=$(awk "BEGIN {printf \"%.2f\", $saved_bytes/1024/1024/1024}")
        local percent=$(awk "BEGIN {printf \"%.1f\", 100 - ($output_bytes * 100 / $input_bytes)}")
        
        # Calculate time taken
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        local elapsed_hours=$(awk "BEGIN {printf \"%.1f\", $elapsed/3600}")
        
        # Move temp to final output
        mv "$temp_file" "$output_file"
        
        echo ""
        echo "✓ Transcode complete!"
        echo "  Input:  $input_size"
        echo "  Output: $output_size"
        echo "  Saved:  ${saved_gb}GB (${percent}% reduction)"
        echo "  Time:   ${elapsed_hours} hours"
        echo "  Output: $(basename "$output_file")"
        echo ""
        echo "⚠️  IMPORTANT: Review the transcoded file before deleting original!"
        echo "   Play it in Jellyfin to verify quality is acceptable."
        echo "   Original file: $(basename "$input_file")"
        echo ""
        
        return 0
    else
        echo ""
        echo "✗ Transcode failed!"
        rm -f "$temp_file"
        return 1
    fi
}

# Process input
if [ -f "$INPUT" ]; then
    # Single file
    transcode_file "$INPUT"
elif [ -d "$INPUT" ]; then
    # Directory - process all MKV files
    echo "Processing all MKV files in: $INPUT"
    echo ""
    
    # Find all MKV files (excluding already transcoded ones)
    readarray -d '' files < <(find "$INPUT" -maxdepth 1 -name "*.mkv" ! -name "*_transcoded.mkv" -type f -print0)
    
    total_files=${#files[@]}
    
    if [ $total_files -eq 0 ]; then
        echo "No MKV files found to transcode"
        exit 0
    fi
    
    echo "Found $total_files file(s) to transcode"
    echo ""
    
    read -p "Continue with batch transcode? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi
    
    # Process each file
    success_count=0
    fail_count=0
    
    for file in "${files[@]}"; do
        if transcode_file "$file"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
        fi
    done
    
    echo ""
    echo "=================================================="
    echo "Batch Transcode Complete"
    echo "=================================================="
    echo "Total files: $total_files"
    echo "Successful:  $success_count"
    echo "Failed:      $fail_count"
    echo "=================================================="
    echo ""
    
    if [ $success_count -gt 0 ]; then
        echo "⚠️  Review all transcoded files before deleting originals!"
        echo ""
        echo "To compare quality:"
        echo "  1. Play original and transcoded in Jellyfin"
        echo "  2. Look for compression artifacts, banding, or blur"
        echo "  3. If satisfied, delete originals and rename transcoded files"
        echo ""
        echo "To rename transcoded files (after verification):"
        echo "  cd '$INPUT'"
        echo "  for f in *_transcoded.mkv; do mv \"\$f\" \"\${f/_transcoded/}\"; done"
        echo ""
    fi
else
    echo "Error: Input must be a file or directory"
    exit 1
fi
