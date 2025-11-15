#!/bin/bash
#
# shellcheck disable=SC2155,SC2034
# analyze-library-quality.sh
# Analyzes video quality of media files to help determine what to keep vs re-rip
#
# Usage: ./analyze-library-quality.sh /path/to/media/directory
#
# Run this on CT303 (analyzer) which has mediainfo installed

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Quality thresholds for home theater
MIN_EXCELLENT_BITRATE_1080P=15000  # kbps - Blu-ray quality
MIN_GOOD_BITRATE_1080P=8000        # kbps - Good quality
MIN_ACCEPTABLE_BITRATE_1080P=5000  # kbps - Acceptable

MIN_EXCELLENT_BITRATE_720P=10000   # kbps
MIN_GOOD_BITRATE_720P=5000         # kbps
MIN_ACCEPTABLE_BITRATE_720P=3000   # kbps

MIN_AUDIO_BITRATE_LOSSLESS=1500    # kbps (DTS-HD, TrueHD)
MIN_AUDIO_BITRATE_GOOD=640         # kbps (DTS, AC3 5.1)

# Check if directory provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 /path/to/media/directory"
    exit 1
fi

MEDIA_DIR="$1"
OUTPUT_FILE="/tmp/media-quality-report-$(date +%Y%m%d-%H%M%S).csv"
OUTPUT_SUMMARY="/tmp/media-quality-summary-$(date +%Y%m%d-%H%M%S).txt"

echo "Analyzing media files in: $MEDIA_DIR"
echo "This may take a while..."
echo ""

# Check for mediainfo
if ! command -v mediainfo &> /dev/null; then
    echo "ERROR: mediainfo is not installed"
    echo "Run this script on CT303 (analyzer container) or install mediainfo"
    exit 1
fi

# Create CSV header
echo "File,Size_GB,Duration_min,Video_Codec,Resolution,Video_Bitrate_kbps,Audio_Codec,Audio_Channels,Audio_Bitrate_kbps,Quality_Score,Recommendation,Notes" > "$OUTPUT_FILE"

# Arrays to store recommendations
declare -a keep_files
declare -a maybe_files
declare -a rerip_files

# Find all video files (excluding samples)
file_count=0
find "$MEDIA_DIR" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" -o -name "*.m4v" \) | grep -vi "sample" | sort | while read -r file; do
    file_count=$((file_count + 1))
    echo -e "${BLUE}[$file_count] Analyzing:${NC} $(basename "$file")"

    # Get file size in GB
    size_bytes=$(stat -c%s "$file" 2>/dev/null || echo "0")
    size_gb=$(echo "scale=2; $size_bytes / 1073741824" | bc)

    # Use mediainfo to extract information
    video_codec=$(mediainfo --Output="Video;%Format%" "$file" | head -1)
    width=$(mediainfo --Output="Video;%Width%" "$file" | head -1)
    height=$(mediainfo --Output="Video;%Height%" "$file" | head -1)
    video_bitrate=$(mediainfo --Output="Video;%BitRate%" "$file" | head -1)

    audio_codec=$(mediainfo --Output="Audio;%Format%" "$file" | head -1)
    audio_channels=$(mediainfo --Output="Audio;%Channels%" "$file" | head -1)
    audio_bitrate=$(mediainfo --Output="Audio;%BitRate%" "$file" | head -1)

    duration_sec=$(mediainfo --Output="General;%Duration%" "$file" | head -1)

    # Calculate duration in minutes
    if [ -n "$duration_sec" ] && [ "$duration_sec" != "" ]; then
        duration_min=$(echo "scale=1; $duration_sec / 60000" | bc)
    else
        duration_min="N/A"
    fi

    # Convert bitrates to kbps
    if [ -n "$video_bitrate" ] && [ "$video_bitrate" != "" ]; then
        video_bitrate_kbps=$(echo "scale=0; $video_bitrate / 1000" | bc)
    else
        video_bitrate_kbps="N/A"
    fi

    if [ -n "$audio_bitrate" ] && [ "$audio_bitrate" != "" ]; then
        audio_bitrate_kbps=$(echo "scale=0; $audio_bitrate / 1000" | bc)
    else
        audio_bitrate_kbps="N/A"
    fi

    # Determine resolution
    resolution="${width}x${height}"

    # Quality scoring and recommendations
    quality_score=0
    notes=""

    # Check video codec (modern codecs score higher)
    case "$video_codec" in
        HEVC|"AVC")
            if [ "$video_codec" == "HEVC" ]; then
                quality_score=$((quality_score + 30))
                notes="${notes}Modern HEVC codec. "
            else
                quality_score=$((quality_score + 25))
                notes="${notes}H.264/AVC codec. "
            fi
            ;;
        MPEG-4*)
            quality_score=$((quality_score + 10))
            notes="${notes}⚠ OLD MPEG-4 codec. "
            ;;
        *)
            quality_score=$((quality_score + 5))
            notes="${notes}⚠ Unknown/old codec ($video_codec). "
            ;;
    esac

    # Check resolution
    if [ -n "$height" ] && [ "$height" != "" ]; then
        if [ "$height" -ge 2160 ]; then
            quality_score=$((quality_score + 40))
            notes="${notes}4K resolution. "
        elif [ "$height" -ge 1080 ]; then
            quality_score=$((quality_score + 35))
            notes="${notes}1080p. "
        elif [ "$height" -ge 720 ]; then
            quality_score=$((quality_score + 20))
            notes="${notes}720p. "
        elif [ "$height" -ge 480 ]; then
            quality_score=$((quality_score + 5))
            notes="${notes}⚠ 480p/DVD quality. "
        else
            notes="${notes}⚠⚠ Very low resolution. "
        fi
    fi

    # Check video bitrate quality (most important for home theater!)
    if [ "$video_bitrate_kbps" != "N/A" ]; then
        if [ "$height" -ge 1080 ]; then
            if [ "$video_bitrate_kbps" -ge "$MIN_EXCELLENT_BITRATE_1080P" ]; then
                quality_score=$((quality_score + 25))
                notes="${notes}★ Excellent bitrate (near Blu-ray). "
            elif [ "$video_bitrate_kbps" -ge "$MIN_GOOD_BITRATE_1080P" ]; then
                quality_score=$((quality_score + 15))
                notes="${notes}Good bitrate. "
            elif [ "$video_bitrate_kbps" -ge "$MIN_ACCEPTABLE_BITRATE_1080P" ]; then
                quality_score=$((quality_score + 5))
                notes="${notes}Acceptable bitrate. "
            else
                notes="${notes}⚠⚠ LOW BITRATE for 1080p (${video_bitrate_kbps}kbps). "
            fi
        elif [ "$height" -ge 720 ]; then
            if [ "$video_bitrate_kbps" -ge "$MIN_EXCELLENT_BITRATE_720P" ]; then
                quality_score=$((quality_score + 20))
                notes="${notes}★ Excellent bitrate. "
            elif [ "$video_bitrate_kbps" -ge "$MIN_GOOD_BITRATE_720P" ]; then
                quality_score=$((quality_score + 15))
                notes="${notes}Good bitrate. "
            elif [ "$video_bitrate_kbps" -ge "$MIN_ACCEPTABLE_BITRATE_720P" ]; then
                quality_score=$((quality_score + 5))
                notes="${notes}Acceptable bitrate. "
            else
                notes="${notes}⚠ Low bitrate for 720p. "
            fi
        fi
    fi

    # Check audio quality (important for home theater!)
    case "$audio_codec" in
        DTS|"DTS-HD"|TrueHD|"FLAC"|"PCM")
            if [[ "$audio_codec" == *"DTS-HD"* ]] || [[ "$audio_codec" == *"TrueHD"* ]]; then
                quality_score=$((quality_score + 15))
                notes="${notes}★ Lossless audio. "
            else
                quality_score=$((quality_score + 10))
                notes="${notes}High-quality audio ($audio_codec). "
            fi
            ;;
        AC-3|"E-AC-3")
            quality_score=$((quality_score + 5))
            notes="${notes}Standard Dolby audio. "
            ;;
        AAC|MP3)
            notes="${notes}⚠ Compressed audio only. "
            ;;
        *)
            notes="${notes}Unknown audio ($audio_codec). "
            ;;
    esac

    # Bonus for surround sound
    if [ -n "$audio_channels" ] && [ "$audio_channels" != "" ]; then
        if [ "$audio_channels" -ge 6 ]; then
            quality_score=$((quality_score + 5))
            notes="${notes}${audio_channels}ch surround. "
        else
            notes="${notes}${audio_channels}ch audio. "
        fi
    fi

    # Final recommendation based on score
    if [ $quality_score -ge 75 ]; then
        recommendation="KEEP"
        notes="${notes}✓ KEEP - Excellent for home theater"
    elif [ $quality_score -ge 60 ]; then
        recommendation="KEEP"
        notes="${notes}✓ KEEP - Good quality"
    elif [ $quality_score -ge 45 ]; then
        recommendation="MAYBE"
        notes="${notes}? MAYBE - Acceptable but not ideal"
    else
        recommendation="RE-RIP"
        notes="${notes}✗ RE-RIP - Buy and rip from Blu-ray"
    fi

    # Write to CSV
    echo "\"$file\",$size_gb,$duration_min,$video_codec,$resolution,$video_bitrate_kbps,$audio_codec,$audio_channels,$audio_bitrate_kbps,$quality_score,$recommendation,\"$notes\"" >> "$OUTPUT_FILE"

    # Print summary
    echo "  Size: ${size_gb}GB | Res: $resolution | Video: $video_codec @ ${video_bitrate_kbps}kbps"
    echo "  Audio: $audio_codec ${audio_channels}ch @ ${audio_bitrate_kbps}kbps"
    if [ $quality_score -ge 75 ]; then
        echo -e "  ${GREEN}Score: $quality_score | $notes${NC}"
    elif [ $quality_score -ge 45 ]; then
        echo -e "  ${YELLOW}Score: $quality_score | $notes${NC}"
    else
        echo -e "  ${RED}Score: $quality_score | $notes${NC}"
    fi
    echo ""
done

echo ""
echo -e "${GREEN}Analysis complete!${NC}"
echo "Report saved to: $OUTPUT_FILE"
echo ""

# Generate summary statistics
echo "Summary Statistics" > "$OUTPUT_SUMMARY"
echo "==================" >> "$OUTPUT_SUMMARY"
echo "" >> "$OUTPUT_SUMMARY"

total_files=$(tail -n +2 "$OUTPUT_FILE" | wc -l | tr -d ' ')
total_size=$(tail -n +2 "$OUTPUT_FILE" | cut -d',' -f2 | paste -sd+ | bc)

keep_count=$(grep -c ",KEEP," "$OUTPUT_FILE" || echo "0")
maybe_count=$(grep -c ",MAYBE," "$OUTPUT_FILE" || echo "0")
rerip_count=$(grep -c ",RE-RIP," "$OUTPUT_FILE" || echo "0")

keep_size=$(grep ",KEEP," "$OUTPUT_FILE" | cut -d',' -f2 | paste -sd+ | bc || echo "0")
maybe_size=$(grep ",MAYBE," "$OUTPUT_FILE" | cut -d',' -f2 | paste -sd+ | bc || echo "0")
rerip_size=$(grep ",RE-RIP," "$OUTPUT_FILE" | cut -d',' -f2 | paste -sd+ | bc || echo "0")

echo "Total files analyzed: $total_files" | tee -a "$OUTPUT_SUMMARY"
echo "Total size: ${total_size}GB" | tee -a "$OUTPUT_SUMMARY"
echo "" | tee -a "$OUTPUT_SUMMARY"
echo -e "${GREEN}KEEP (high quality):${NC} $keep_count files (${keep_size}GB)" | tee -a "$OUTPUT_SUMMARY"
echo -e "${YELLOW}MAYBE (acceptable):${NC} $maybe_count files (${maybe_size}GB)" | tee -a "$OUTPUT_SUMMARY"
echo -e "${RED}RE-RIP (low quality):${NC} $rerip_count files (${rerip_size}GB)" | tee -a "$OUTPUT_SUMMARY"
echo "" | tee -a "$OUTPUT_SUMMARY"

# Show top files to re-rip
echo "Top candidates to RE-RIP (buy Blu-ray):" | tee -a "$OUTPUT_SUMMARY"
echo "=======================================" | tee -a "$OUTPUT_SUMMARY"
tail -n +2 "$OUTPUT_FILE" | grep ",RE-RIP," | sort -t',' -k10 -n | head -20 | while IFS=, read -r file size rest; do
    basename_file=$(basename "$file" | sed 's/"//g')
    echo "  - $basename_file (${size}GB)" | tee -a "$OUTPUT_SUMMARY"
done
echo "" | tee -a "$OUTPUT_SUMMARY"

echo "Files to KEEP:" | tee -a "$OUTPUT_SUMMARY"
echo "==============" | tee -a "$OUTPUT_SUMMARY"
tail -n +2 "$OUTPUT_FILE" | grep ",KEEP," | sort -t',' -k10 -n -r | while IFS=, read -r file size rest; do
    basename_file=$(basename "$file" | sed 's/"//g')
    echo "  - $basename_file (${size}GB)" | tee -a "$OUTPUT_SUMMARY"
done
echo "" | tee -a "$OUTPUT_SUMMARY"

echo ""
echo "Detailed report: $OUTPUT_FILE"
echo "Summary report: $OUTPUT_SUMMARY"
echo ""
echo "Recommendations:"
echo "  1. Review files marked 'RE-RIP' - consider buying Blu-ray and ripping properly"
echo "  2. Files marked 'MAYBE' may be acceptable for less critical content"
echo "  3. Files marked 'KEEP' are good quality for your home theater setup"
echo "  4. For home theater, prioritize:"
echo "     - 1080p or higher resolution"
echo "     - Video bitrate 8000+ kbps (15000+ for near Blu-ray quality)"
echo "     - DTS/DTS-HD or better audio"
echo "     - 5.1+ surround sound"
