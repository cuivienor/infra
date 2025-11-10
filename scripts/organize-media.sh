#!/bin/bash
# organize-media.sh - Interactive organize/multiplex workflow
#
# Usage: ./organize-media.sh "/path/to/staging/folder"
#
# This script will:
# 1. Analyze all MKV files in the folder
# 2. Show audio/subtitle tracks
# 3. Ask if you want to filter to English and Bulgarian only
# 4. Process and replace the original file

INPUT_DIR="$1"
LANGUAGES="eng,bul"  # English and Bulgarian only

if [ -z "$INPUT_DIR" ]; then
    echo "Usage: $0 /path/to/staging/folder"
    echo ""
    echo "Example:"
    echo "  $0 /mnt/storage/media/staging/Dragon"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Directory does not exist: $INPUT_DIR"
    exit 1
fi

echo "=================================================="
echo "Media Organization & Track Filtering"
echo "=================================================="
echo "Directory: $INPUT_DIR"
echo "Languages: English (eng), Bulgarian (bul)"
echo "=================================================="
echo ""

# Check if required tools are installed
for tool in mkvmerge jq; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is not installed"
        echo "Install with: apt install mkvtoolnix jq"
        exit 1
    fi
done

# Function to analyze a file
analyze_file() {
    local file="$1"
    echo ""
    echo "--- File: $(basename "$file") ---"
    echo "DEBUG: Full path: '$file'"
    echo "DEBUG: Path length: ${#file}"
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "Error: File not found!"
        echo "DEBUG: File check failed for: '$file'"
        return 1
    fi
    
    # Get file size
    local size=$(du -h -- "$file" 2>/dev/null | cut -f1)
    echo "Size: ${size:-unknown}"
    echo ""
    
    # Get JSON data from mkvmerge (with error checking)
    local json_data=$(mkvmerge -J "$file" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$json_data" ]; then
        echo "Error: Could not read file with mkvmerge"
        return 1
    fi
    
    # Show video tracks
    echo "VIDEO TRACKS:"
    echo "$json_data" | jq -r '
        .tracks[] | 
        select(.type == "video") | 
        "  Track \(.id): \(.codec) | \(.properties.pixel_dimensions) | \(.properties.display_dimensions)"
    ' 2>/dev/null || echo "  (none or error reading tracks)"
    
    echo ""
    echo "AUDIO TRACKS:"
    echo "$json_data" | jq -r '
        .tracks[] | 
        select(.type == "audio") | 
        "  Track \(.id): \(.codec) | Lang: \(.properties.language // "und") | Channels: \(.properties.audio_channels) | \(.properties.track_name // "unnamed")"
    ' 2>/dev/null || echo "  (none or error reading tracks)"
    
    echo ""
    echo "SUBTITLE TRACKS:"
    echo "$json_data" | jq -r '
        .tracks[] | 
        select(.type == "subtitles") | 
        "  Track \(.id): \(.codec) | Lang: \(.properties.language // "und") | \(.properties.track_name // "unnamed")"
    ' 2>/dev/null || echo "  (none or error reading tracks)"
    
    echo ""
    
    # Count tracks that will be kept
    local eng_bul_audio=$(echo "$json_data" | jq '
        [.tracks[] | 
         select(.type == "audio" and (.properties.language == "eng" or .properties.language == "bul"))] | length
    ' 2>/dev/null || echo "0")
    
    local eng_bul_subs=$(echo "$json_data" | jq '
        [.tracks[] | 
         select(.type == "subtitles" and (.properties.language == "eng" or .properties.language == "bul"))] | length
    ' 2>/dev/null || echo "0")
    
    local other_audio=$(echo "$json_data" | jq '
        [.tracks[] | 
         select(.type == "audio" and .properties.language != "eng" and .properties.language != "bul")] | length
    ' 2>/dev/null || echo "0")
    
    local other_subs=$(echo "$json_data" | jq '
        [.tracks[] | 
         select(.type == "subtitles" and .properties.language != "eng" and .properties.language != "bul")] | length
    ' 2>/dev/null || echo "0")
    
    echo "SUMMARY:"
    echo "  Will KEEP: $eng_bul_audio audio + $eng_bul_subs subtitle tracks (English/Bulgarian)"
    echo "  Will REMOVE: $other_audio audio + $other_subs subtitle tracks (other languages)"
    echo ""
    
    return 0
}

# Function to filter tracks
filter_tracks() {
    local file="$1"
    local temp_file="${file%.*}_temp.mkv"
    local backup_file="${file%.*}_backup.mkv"
    
    echo "→ Filtering tracks to English and Bulgarian only..."
    
    # Create backup
    cp "$file" "$backup_file"
    echo "  Created backup: $(basename "$backup_file")"
    
    # Get all track IDs for English and Bulgarian
    local audio_tracks=$(mkvmerge -J "$file" 2>/dev/null | jq -r '
        [.tracks[] | 
         select(.type == "audio" and (.properties.language == "eng" or .properties.language == "bul")) | 
         .id] | join(",")')
    
    local subtitle_tracks=$(mkvmerge -J "$file" 2>/dev/null | jq -r '
        [.tracks[] | 
         select(.type == "subtitles" and (.properties.language == "eng" or .properties.language == "bul")) | 
         .id] | join(",")')
    
    # Build mkvmerge command
    local cmd="mkvmerge -o \"$temp_file\""
    
    # Add audio tracks (or no audio if none found)
    if [ -n "$audio_tracks" ] && [ "$audio_tracks" != "" ]; then
        cmd="$cmd --audio-tracks $audio_tracks"
    else
        cmd="$cmd --no-audio"
        echo "  Warning: No English/Bulgarian audio tracks found"
    fi
    
    # Add subtitle tracks (or no subtitles if none found)
    if [ -n "$subtitle_tracks" ] && [ "$subtitle_tracks" != "" ]; then
        cmd="$cmd --subtitle-tracks $subtitle_tracks"
    else
        cmd="$cmd --no-subtitles"
        echo "  Warning: No English/Bulgarian subtitle tracks found"
    fi
    
    cmd="$cmd \"$file\""
    
    # Execute
    echo "  Running mkvmerge..."
    eval $cmd > /dev/null 2>&1
    
    if [ $? -eq 0 ] && [ -f "$temp_file" ]; then
        # Compare sizes
        local orig_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
        local new_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null || echo "0")
        
        if [ "$orig_size" -gt 0 ] && [ "$new_size" -gt 0 ]; then
            local saved=$((orig_size - new_size))
            local saved_mb=$((saved / 1024 / 1024))
            local percent=$((100 - (new_size * 100 / orig_size)))
            
            # Replace original
            mv "$temp_file" "$file"
            
            echo "✓ Successfully filtered: $(basename "$file")"
            echo "  Space saved: ${saved_mb}MB (${percent}% reduction)"
            echo "  Backup: $(basename "$backup_file")"
            echo ""
            return 0
        else
            echo "✗ Error: Could not determine file sizes"
            rm -f "$temp_file"
            mv "$backup_file" "$file"
            return 1
        fi
    else
        echo "✗ Failed to filter: $(basename "$file")"
        rm -f "$temp_file"
        # Restore from backup if something went wrong
        if [ -f "$backup_file" ]; then
            mv "$backup_file" "$file"
            echo "  Restored from backup"
        fi
        return 1
    fi
}

# Main processing loop
file_count=0
processed_count=0

# Build array of MKV files using glob (handles spaces correctly)
shopt -s nullglob
files=("$INPUT_DIR"/*.mkv)
shopt -u nullglob

# Sort the array using printf for proper newline handling
readarray -t sorted_files < <(printf '%s\n' "${files[@]}" | sort)

total_files=${#sorted_files[@]}

if [ $total_files -eq 0 ]; then
    echo "No MKV files found in: $INPUT_DIR"
    exit 0
fi

echo "Found $total_files MKV file(s) to process"
echo ""

# DEBUG: Show what's in the array
echo "DEBUG: Files in array:"
printf 'DEBUG: [%s]\n' "${sorted_files[@]}"
echo ""

# Process each file
for file in "${sorted_files[@]}"; do
    file_count=$((file_count + 1))
    
    echo "=================================================="
    echo "File $file_count of $total_files"
    echo "=================================================="
    
    if ! analyze_file "$file"; then
        echo "→ Skipping due to error"
        echo ""
        continue
    fi
    
    read -p "Filter this file? (y/n/q to quit): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Qq]$ ]]; then
        echo ""
        echo "Quitting..."
        exit 0
    elif [[ $REPLY =~ ^[Yy]$ ]]; then
        if filter_tracks "$file"; then
            processed_count=$((processed_count + 1))
        fi
    else
        echo "→ Skipped"
        echo ""
    fi
done

echo ""
echo "=================================================="
echo "✓ Processing complete!"
echo "  Files checked: $total_files"
echo "  Files processed: $processed_count"
echo "=================================================="
