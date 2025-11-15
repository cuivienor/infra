#!/bin/bash
# analyze-media.sh - Analyze MKV files and detect duplicates
# shellcheck disable=SC2155,SC2034
#
# Usage: ./analyze-media.sh "/path/to/staging/folder"

INPUT_DIR="$1"

if [ -z "$INPUT_DIR" ]; then
    echo "Usage: $0 /path/to/staging/folder"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Directory does not exist: $INPUT_DIR"
    exit 1
fi

# Check if required tools are installed
for tool in mkvmerge jq mediainfo; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is not installed"
        exit 1
    fi
done

echo "=================================================="
echo "Media File Analysis"
echo "=================================================="
echo "Directory: $INPUT_DIR"
echo ""
echo "Analyzing files..."
echo ""

# Temporary file to store results
TMPFILE=$(mktemp)
trap 'rm -f $TMPFILE' EXIT

# Analyze each MKV file
find "$INPUT_DIR" -maxdepth 1 -name "*.mkv" -type f -print0 | while IFS= read -r -d '' file; do
    filename=$(basename "$file")

    # Get JSON metadata
    json=$(mkvmerge -J "$file" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$json" ]; then
        # Extract duration (in nanoseconds, convert to minutes)
        duration_ns=$(echo "$json" | jq -r '.container.properties.duration // 0')
        duration_min=$((duration_ns / 1000000000 / 60))

        # Extract video info
        resolution=$(echo "$json" | jq -r '.tracks[] | select(.type == "video") | .properties.pixel_dimensions' | head -1)

        # Count tracks
        video_count=$(echo "$json" | jq '[.tracks[] | select(.type == "video")] | length')
        audio_count=$(echo "$json" | jq '[.tracks[] | select(.type == "audio")] | length')
        subtitle_count=$(echo "$json" | jq '[.tracks[] | select(.type == "subtitles")] | length')
    else
        duration_min=0
        resolution="unknown"
        video_count=0
        audio_count=0
        subtitle_count=0
    fi

    # Get file size in GB
    size_bytes=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    size_gb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1024/1024/1024}")

    # Write to temp file
    echo "$filename|$size_gb|$duration_min|$resolution|$video_count|$audio_count|$subtitle_count" >> "$TMPFILE"
done

echo "=================================================="
echo "FILE ANALYSIS SUMMARY"
echo "=================================================="
echo ""

printf "%-45s %8s %10s %12s %3s %3s %3s\n" "FILENAME" "SIZE" "DURATION" "RESOLUTION" "V" "A" "S"
printf "%-45s %8s %10s %12s %3s %3s %3s\n" "--------" "----" "--------" "----------" "-" "-" "-"

# Sort by size (descending) and display
sort -t'|' -k2 -rn "$TMPFILE" | while IFS='|' read -r filename size_gb duration_min resolution v a s; do
    printf "%-45s %7sG %9dm %12s %3d %3d %3d\n" "$filename" "$size_gb" "$duration_min" "$resolution" "$v" "$a" "$s"
done

echo ""
echo "=================================================="
echo "DUPLICATE DETECTION"
echo "=================================================="
echo ""

# Find potential duplicates (files >30 min with similar duration/size)
while IFS='|' read -r file1 size1 dur1 res1 v1 a1 s1; do
    # Skip short files
    if [ "$dur1" -lt 30 ]; then
        continue
    fi

    found_dups=0

    while IFS='|' read -r file2 size2 dur2 res2 v2 a2 s2; do
        if [ "$file1" = "$file2" ]; then
            continue
        fi

        # Skip short files
        if [ "$dur2" -lt 30 ]; then
            continue
        fi

        # Check if durations within 5 minutes
        dur_diff=$(( (dur1 - dur2) ))
        dur_diff=${dur_diff#-}  # abs value

        if [ "$dur_diff" -lt 5 ]; then
            if [ "$found_dups" -eq 0 ]; then
                echo "⚠️  POTENTIAL DUPLICATES:"
                echo "   → $file1 (${size1}GB, ${dur1}min)"
                found_dups=1
            fi
            echo "   → $file2 (${size2}GB, ${dur2}min)"
        fi
    done < "$TMPFILE"

    if [ "$found_dups" -eq 1 ]; then
        echo ""
    fi
done < "$TMPFILE"

echo "=================================================="
echo "CATEGORIZATION"
echo "=================================================="
echo ""

echo "MAIN FEATURES (>30 min, >5GB):"
while IFS='|' read -r filename size dur res v a s; do
    if [ "$dur" -gt 30 ] && [ "$(awk "BEGIN {print ($size > 5) ? 1 : 0}")" -eq 1 ]; then
        printf "  ✓ %-45s %7sG %9dm\n" "$filename" "$size" "$dur"
    fi
done < "$TMPFILE"

echo ""
echo "EXTRAS/FEATURES (2-30 min OR 1-5GB):"
while IFS='|' read -r filename size dur res v a s; do
    size_ok=$(awk "BEGIN {print ($size >= 1 && $size <= 5) ? 1 : 0}")
    if ([ "$dur" -ge 2 ] && [ "$dur" -le 30 ]) || [ "$size_ok" -eq 1 ]; then
        printf "  ⭐ %-45s %7sG %9dm\n" "$filename" "$size" "$dur"
    fi
done < "$TMPFILE"

echo ""
echo "SHORT CLIPS (<2 min OR <1GB):"
while IFS='|' read -r filename size dur res v a s; do
    if [ "$dur" -lt 2 ] || [ "$(awk "BEGIN {print ($size < 1) ? 1 : 0}")" -eq 1 ]; then
        printf "  📎 %-45s %7sG %9dm\n" "$filename" "$size" "$dur"
    fi
done < "$TMPFILE"

echo ""
echo "=================================================="
echo "RECOMMENDATIONS"
echo "=================================================="
echo ""
echo "1. Review potential duplicates above"
echo "2. Compare duplicates in Jellyfin (play first 30 sec)"
echo "3. Check for language-specific video or commentary audio"
echo "4. Keep one copy of duplicates, delete the rest"
echo ""
echo "To compare two files:"
echo "  mediainfo 'file1.mkv' > /tmp/file1.txt"
echo "  mediainfo 'file2.mkv' > /tmp/file2.txt"
echo "  diff /tmp/file1.txt /tmp/file2.txt"
echo ""

# Save analysis to file
ANALYSIS_FILE="$INPUT_DIR/.analysis.txt"
echo "Saving analysis to: $ANALYSIS_FILE"

{
    echo "Media File Analysis"
    echo "Generated: $(date)"
    echo "Directory: $INPUT_DIR"
    echo ""
    echo "=================================================="
    echo "FILE ANALYSIS SUMMARY"
    echo "=================================================="
    echo ""

    printf "%-45s %8s %10s %12s %3s %3s %3s\n" "FILENAME" "SIZE" "DURATION" "RESOLUTION" "V" "A" "S"
    printf "%-45s %8s %10s %12s %3s %3s %3s\n" "--------" "----" "--------" "----------" "-" "-" "-"

    sort -t'|' -k2 -rn "$TMPFILE" | while IFS='|' read -r filename size_gb duration_min resolution v a s; do
        printf "%-45s %7sG %9dm %12s %3d %3d %3d\n" "$filename" "$size_gb" "$duration_min" "$resolution" "$v" "$a" "$s"
    done

    echo ""
    echo "=================================================="
    echo "DUPLICATE DETECTION"
    echo "=================================================="
    echo ""

    # Repeat duplicate detection for file
    found_any=0
    while IFS='|' read -r file1 size1 dur1 res1 v1 a1 s1; do
        if [ "$dur1" -lt 30 ]; then
            continue
        fi

        found_dups=0

        while IFS='|' read -r file2 size2 dur2 res2 v2 a2 s2; do
            if [ "$file1" = "$file2" ]; then
                continue
            fi

            if [ "$dur2" -lt 30 ]; then
                continue
            fi

            dur_diff=$(( (dur1 - dur2) ))
            dur_diff=${dur_diff#-}

            if [ "$dur_diff" -lt 5 ]; then
                if [ "$found_dups" -eq 0 ]; then
                    echo "⚠️  POTENTIAL DUPLICATES:"
                    echo "   → $file1 (${size1}GB, ${dur1}min)"
                    found_dups=1
                    found_any=1
                fi
                echo "   → $file2 (${size2}GB, ${dur2}min)"
            fi
        done < "$TMPFILE"

        if [ "$found_dups" -eq 1 ]; then
            echo ""
        fi
    done < "$TMPFILE"

    if [ "$found_any" -eq 0 ]; then
        echo "(no duplicates detected)"
        echo ""
    fi

    echo "=================================================="
    echo "CATEGORIZATION"
    echo "=================================================="
    echo ""

    echo "MAIN FEATURES (>30 min, >5GB):"
    while IFS='|' read -r filename size dur res v a s; do
        if [ "$dur" -gt 30 ] && [ "$(awk "BEGIN {print ($size > 5) ? 1 : 0}")" -eq 1 ]; then
            printf "  ✓ %-45s %7sG %9dm\n" "$filename" "$size" "$dur"
        fi
    done < "$TMPFILE"

    echo ""
    echo "EXTRAS/FEATURES (2-30 min OR 1-5GB):"
    while IFS='|' read -r filename size dur res v a s; do
        size_ok=$(awk "BEGIN {print ($size >= 1 && $size <= 5) ? 1 : 0}")
        if ([ "$dur" -ge 2 ] && [ "$dur" -le 30 ]) || [ "$size_ok" -eq 1 ]; then
            printf "  ⭐ %-45s %7sG %9dm\n" "$filename" "$size" "$dur"
        fi
    done < "$TMPFILE"

    echo ""
    echo "SHORT CLIPS (<2 min OR <1GB):"
    while IFS='|' read -r filename size dur res v a s; do
        if [ "$dur" -lt 2 ] || [ "$(awk "BEGIN {print ($size < 1) ? 1 : 0}")" -eq 1 ]; then
            printf "  📎 %-45s %7sG %9dm\n" "$filename" "$size" "$dur"
        fi
    done < "$TMPFILE"

} > "$ANALYSIS_FILE"

echo "✓ Analysis saved"
echo ""
