#!/bin/bash
#
# organize-legacy-with-filebot.sh
# Organizes legacy media files using FileBot for proper naming and structure
#
# This script processes files from staging to library with FileBot's naming conventions
# Suitable for CT303 (analyzer) which has FileBot installed
#

set -euo pipefail

# Check if running on analyzer container (has FileBot)
if ! command -v filebot &> /dev/null; then
    echo "Error: FileBot is not installed"
    echo "Run this script on CT303 (analyzer container) or install FileBot"
    exit 1
fi

# Paths (CT303 mount points)
STAGING_DIR="/mnt/media/staging/2-ready"
LIBRARY_DIR="/mnt/media/library"

# Create staging directories
mkdir -p "$STAGING_DIR/movies"
mkdir -p "$STAGING_DIR/tv"

echo "================================================"
echo "Legacy Media Organization with FileBot"
echo "================================================"
echo ""
echo "This will:"
echo "  1. Copy top-tier legacy files to staging"
echo "  2. Use FileBot to rename and organize them"
echo "  3. Move organized files to library"
echo ""
echo "Staging: $STAGING_DIR"
echo "Library: $LIBRARY_DIR"
echo ""

# Check if migration script has been run
movie_count=$(find "$STAGING_DIR/movies" -name "*.mkv" -type f 2>/dev/null | wc -l || echo "0")
tv_count=$(find "$STAGING_DIR/tv" -name "*.mkv" -type f 2>/dev/null | wc -l || echo "0")

if [ "$movie_count" -eq 0 ] && [ "$tv_count" -eq 0 ]; then
    echo "No files found in staging directory."
    echo ""
    echo "First, run the migration script:"
    echo "  ~/scripts/migrate-top-tier-to-library.sh"
    echo ""
    exit 1
fi

echo "Files in staging:"
echo "  Movies: $movie_count"
echo "  TV: $tv_count"
echo ""

# FileBot format strings (Plex/Jellyfin compatible)
MOVIE_FORMAT='{n} ({y})/{n} ({y})'
TV_FORMAT='{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}'

# Process movies
if [ "$movie_count" -gt 0 ]; then
    echo "================================================"
    echo "Processing Movies with FileBot"
    echo "================================================"
    echo ""
    
    # List files to process
    echo "Movies to process:"
    find "$STAGING_DIR/movies" -name "*.mkv" -type f -exec basename {} \; | sort
    echo ""
    
    echo "Running FileBot DRY RUN..."
    echo "========================================"
    
    # Run dry-run first
    filebot -rename "$STAGING_DIR/movies" \
        --db TheMovieDB \
        --output "$LIBRARY_DIR" \
        --format "$MOVIE_FORMAT" \
        --action test \
        -non-strict || true
    
    echo ""
    echo "========================================"
    echo ""
    
    read -p "Execute movie organization? [y/N]: " -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Organizing movies..."
        echo ""
        
        filebot -rename "$STAGING_DIR/movies" \
            --db TheMovieDB \
            --output "$LIBRARY_DIR" \
            --format "$MOVIE_FORMAT" \
            --action move \
            -non-strict
        
        echo ""
        echo "✓ Movies organized successfully!"
        echo ""
        
        # Check remaining files
        remaining=$(find "$STAGING_DIR/movies" -name "*.mkv" -type f 2>/dev/null | wc -l || echo "0")
        if [ "$remaining" -gt 0 ]; then
            echo "⚠️  Warning: $remaining file(s) were not processed"
            echo "Check: $STAGING_DIR/movies"
        fi
    else
        echo "Skipped movie organization"
    fi
    echo ""
fi

# Process TV shows
if [ "$tv_count" -gt 0 ]; then
    echo "================================================"
    echo "Processing TV Shows with FileBot"
    echo "================================================"
    echo ""
    
    # List files to process
    echo "TV episodes to process:"
    find "$STAGING_DIR/tv" -name "*.mkv" -type f -exec basename {} \; | sort
    echo ""
    
    echo "Running FileBot DRY RUN..."
    echo "========================================"
    
    # Run dry-run first
    filebot -rename "$STAGING_DIR/tv" \
        --db TheTVDB \
        --output "$LIBRARY_DIR" \
        --format "$TV_FORMAT" \
        --action test \
        -non-strict || true
    
    echo ""
    echo "========================================"
    echo ""
    
    read -p "Execute TV show organization? [y/N]: " -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Organizing TV shows..."
        echo ""
        
        filebot -rename "$STAGING_DIR/tv" \
            --db TheTVDB \
            --output "$LIBRARY_DIR" \
            --format "$TV_FORMAT" \
            --action move \
            -non-strict
        
        echo ""
        echo "✓ TV shows organized successfully!"
        echo ""
        
        # Check remaining files
        remaining=$(find "$STAGING_DIR/tv" -name "*.mkv" -type f 2>/dev/null | wc -l || echo "0")
        if [ "$remaining" -gt 0 ]; then
            echo "⚠️  Warning: $remaining file(s) were not processed"
            echo "Check: $STAGING_DIR/tv"
        fi
    else
        echo "Skipped TV show organization"
    fi
    echo ""
fi

echo "================================================"
echo "Organization Complete"
echo "================================================"
echo ""
echo "Library location: $LIBRARY_DIR"
echo ""
echo "Next steps:"
echo "  1. Verify files in library:"
echo "     ls -R $LIBRARY_DIR"
echo "  2. Check Jellyfin to confirm new content appears"
echo "  3. Run a library scan in Jellyfin if needed"
echo "  4. Once verified, you can delete staging files:"
echo "     rm -rf $STAGING_DIR/movies/* $STAGING_DIR/tv/*"
echo ""
