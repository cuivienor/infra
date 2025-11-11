#!/bin/bash
# filebot-process.sh - Process media with FileBot (semi-automated with preview)
#
# Usage: ./filebot-process.sh /path/to/4-ready/[type]/[folder]
#
# This script will:
# 1. Detect type (movie or TV)
# 2. Run FileBot dry-run to preview changes
# 3. Confirm before executing
# 4. Move files to final library with proper naming

set -e

INPUT_DIR="$1"

if [ -z "$INPUT_DIR" ]; then
    echo "Usage: $0 /path/to/4-ready/[type]/[folder]"
    echo ""
    echo "Examples:"
    echo "  $0 /staging/4-ready/movies/How_To_Train_Your_Dragon/"
    echo "  $0 /staging/4-ready/tv/Avatar_The_Last_Airbender/Season_01/"
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Directory does not exist: $INPUT_DIR"
    exit 1
fi

# Check if filebot is installed
if ! command -v filebot &> /dev/null; then
    echo "Error: FileBot is not installed"
    echo ""
    echo "Install FileBot: https://www.filebot.net/"
    exit 1
fi

# Verify this is from 4-ready
if [[ ! "$INPUT_DIR" =~ staging/4-ready ]]; then
    echo "⚠️  Warning: This script is designed for staging/4-ready paths"
    echo "Your path: $INPUT_DIR"
    echo ""
    read -p "Continue anyway? [y/N]: " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 0
    fi
    echo ""
fi

# Detect type (movies or tv)
if [[ "$INPUT_DIR" =~ /movies/ ]]; then
    TYPE="movies"
    DB="TheMovieDB"
    FORMAT='{n} ({y})/{n} ({y})'
elif [[ "$INPUT_DIR" =~ /tv/ ]]; then
    TYPE="tv"
    DB="TheTVDB"
    FORMAT='{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}'
else
    echo "Error: Cannot determine type (movies or tv) from path"
    exit 1
fi

OUTPUT_DIR="/mnt/storage/media/library/${TYPE}"

echo "=========================================="
echo "FileBot Processing (DRY RUN)"
echo "=========================================="
echo "Type:     $TYPE"
echo "Database: $DB"
echo "Format:   $FORMAT"
echo ""
echo "Input:    $INPUT_DIR"
echo "Output:   $OUTPUT_DIR"
echo "=========================================="
echo ""

# Count files
file_count=$(find "$INPUT_DIR" -type f -name "*.mkv" | wc -l)
echo "Files to process: $file_count"
echo ""

if [ $file_count -eq 0 ]; then
    echo "No MKV files found to process"
    exit 1
fi

echo "Running FileBot dry-run to preview changes..."
echo ""
echo "========================================"
echo ""

# Run dry-run
filebot -rename "$INPUT_DIR" \
    --db "$DB" \
    --output "$OUTPUT_DIR" \
    --format "$FORMAT" \
    --action test \
    -non-strict \
    || {
        echo ""
        echo "✗ FileBot dry-run failed"
        echo ""
        echo "Common issues:"
        echo "  - Files not recognized by database"
        echo "  - Incorrect folder/file naming"
        echo "  - Missing season/episode information"
        echo ""
        echo "Try manually searching or adjusting folder names"
        exit 1
    }

echo ""
echo "========================================"
echo ""

read -p "Execute this rename/move operation? [y/N]: " -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted - no changes made"
    exit 0
fi

# Execute actual rename/move
echo ""
echo "Executing FileBot rename/move..."
echo ""

filebot -rename "$INPUT_DIR" \
    --db "$DB" \
    --output "$OUTPUT_DIR" \
    --format "$FORMAT" \
    --action move \
    -non-strict

filebot_exit=$?

echo ""

if [ $filebot_exit -eq 0 ]; then
    echo "=========================================="
    echo "✓ Success!"
    echo "=========================================="
    echo "Files moved to library: $OUTPUT_DIR"
    echo ""
    
    # Check if input directory is now empty
    remaining_files=$(find "$INPUT_DIR" -type f -name "*.mkv" | wc -l)
    
    if [ $remaining_files -eq 0 ]; then
        echo "Input directory is now empty"
        read -p "Delete empty directory structure? [Y/n]: " -r
        echo
        
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            rm -rf "$INPUT_DIR"
            echo "✓ Cleaned up: $INPUT_DIR"
        fi
    else
        echo "⚠️  Warning: $remaining_files file(s) remain in input"
        echo "These may have failed to process"
        echo "Check: $INPUT_DIR"
    fi
    
    echo ""
    echo "Jellyfin will automatically detect new content"
    echo "You may need to run a library scan to update metadata"
else
    echo "=========================================="
    echo "✗ FileBot execution failed"
    echo "=========================================="
    echo "Files remain at: $INPUT_DIR"
    echo ""
    echo "Check errors above for details"
    exit 1
fi

echo ""
