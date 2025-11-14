#!/bin/bash
# filebot-process.sh - Process media with FileBot (semi-automated with preview + extras support)
#
# Usage: ./filebot-process.sh /path/to/3-transcoded/[type]/[folder]
#
# This script will:
# 1. Detect type (movie or TV)
# 2. Detect and preserve extras folders
# 3. Run FileBot dry-run to preview changes
# 4. Confirm before executing
# 5. Move files to final library with proper naming
# 6. Copy extras to library location

set -e

INPUT_DIR="$1"

if [ -z "$INPUT_DIR" ]; then
    echo "Usage: $0 /path/to/3-transcoded/[type]/[folder]"
    echo ""
    echo "Examples:"
    echo "  $0 /mnt/staging/3-transcoded/movies/How_To_Train_Your_Dragon/"
    echo "  $0 /mnt/staging/3-transcoded/tv/Avatar_The_Last_Airbender/Season_01/"
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

# Detect type (movies or tv)
if [[ "$INPUT_DIR" =~ /movies/ ]]; then
    TYPE="movies"
    DB="TheMovieDB"
    FORMAT='{n} ({y})/{n} ({y})'
    # For movies, extract potential year from directory name for better matching
    MOVIE_HINT=$(basename "$INPUT_DIR" | tr '_' ' ')
elif [[ "$INPUT_DIR" =~ /tv/ ]]; then
    TYPE="tv"
    DB="TheTVDB"
    FORMAT='{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}'
else
    echo "Error: Cannot determine type (movies or tv) from path"
    exit 1
fi

# Determine output directory based on mount point
# CT303 has /mnt/library, other containers might have /mnt/storage/media/library
if [ -d "/mnt/library" ]; then
    OUTPUT_DIR="/mnt/library/${TYPE}"
else
    OUTPUT_DIR="/mnt/storage/media/library/${TYPE}"
fi

# Check for extras subdirectories (Jellyfin-supported types)
EXTRAS_FOUND=()
EXTRAS_TYPES=("extras" "behind the scenes" "deleted scenes" "interviews" "scenes" "samples" "shorts" "featurettes" "clips" "trailers" "other")

for extras_type in "${EXTRAS_TYPES[@]}"; do
    if [ -d "$INPUT_DIR/$extras_type" ]; then
        extras_count=$(find "$INPUT_DIR/$extras_type" -type f -name "*.mkv" 2>/dev/null | wc -l)
        if [ $extras_count -gt 0 ]; then
            EXTRAS_FOUND+=("$extras_type:$extras_count")
        fi
    fi
done

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

# Count main content files (exclude extras directories)
exclude_pattern=""
for extras_type in "${EXTRAS_TYPES[@]}"; do
    exclude_pattern="$exclude_pattern -not -path \"*/$extras_type/*\""
done

file_count=$(eval "find \"$INPUT_DIR\" -type f -name \"*.mkv\" $exclude_pattern" | wc -l)
echo "Main content files: $file_count"

# Show extras summary
if [ ${#EXTRAS_FOUND[@]} -gt 0 ]; then
    echo ""
    echo "Extras detected:"
    for extra_info in "${EXTRAS_FOUND[@]}"; do
        IFS=':' read -r extra_type extra_count <<< "$extra_info"
        echo "  - $extra_type/ ($extra_count files)"
    done
    echo ""
    echo "ℹ️  Extras will be copied to library after main content is processed"
fi

echo ""

if [ $file_count -eq 0 ]; then
    echo "No main content MKV files found to process"
    echo "(Extras alone cannot be processed without main content)"
    exit 1
fi

echo "Running FileBot test to preview changes..."
echo ""
echo "========================================"
echo ""

# Run FileBot in test mode (dry-run) with licensed version
# Note: FileBot may return non-zero exit codes even on success with -non-strict
# So we capture output and check if files were processed instead
if [ "$TYPE" = "movies" ]; then
    # For movies, use query hint from directory name for better matching
    filebot_test_output=$(filebot -rename "$INPUT_DIR" \
        --db "$DB" \
        --q "$MOVIE_HINT" \
        --output "$OUTPUT_DIR" \
        --format "$FORMAT" \
        --action test \
        -non-strict 2>&1)
    filebot_test_exit=$?
    
    echo "$filebot_test_output"
    
    # Check if any files were processed (look for [TEST] or "Processed" in output)
    if ! echo "$filebot_test_output" | grep -q -E '\[TEST\]|Processed [0-9]+ file'; then
        echo ""
        echo "✗ FileBot dry-run failed - no files processed"
        echo ""
        echo "Common issues:"
        echo "  - Movie not found in database"
        echo "  - Ambiguous title (multiple matches)"
        echo "  - Year might be needed for disambiguation"
        echo ""
        echo "Hint: Try renaming directory to include year, e.g. 'Movie_Name_2010'"
        exit 1
    fi
else
    # For TV shows, standard query
    filebot_test_output=$(filebot -rename "$INPUT_DIR" \
        --db "$DB" \
        --output "$OUTPUT_DIR" \
        --format "$FORMAT" \
        --action test \
        -non-strict 2>&1)
    filebot_test_exit=$?
    
    echo "$filebot_test_output"
    
    # Check if any files were processed
    if ! echo "$filebot_test_output" | grep -q -E '\[TEST\]|Processed [0-9]+ file'; then
        echo ""
        echo "✗ FileBot dry-run failed - no files processed"
        echo ""
        echo "Common issues:"
        echo "  - Show not recognized by database"
        echo "  - Incorrect folder/file naming"
        echo "  - Missing season/episode information"
        echo ""
        echo "Try manually searching or adjusting folder names"
        exit 1
    fi
fi

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

# Run FileBot with proper query for movies vs TV
if [ "$TYPE" = "movies" ]; then
    filebot_output=$(filebot -rename "$INPUT_DIR" \
        --db "$DB" \
        --q "$MOVIE_HINT" \
        --output "$OUTPUT_DIR" \
        --format "$FORMAT" \
        --action move \
        -non-strict 2>&1)
else
    filebot_output=$(filebot -rename "$INPUT_DIR" \
        --db "$DB" \
        --output "$OUTPUT_DIR" \
        --format "$FORMAT" \
        --action move \
        -non-strict 2>&1)
fi

filebot_exit=$?

echo "$filebot_output"
echo ""

if [ $filebot_exit -eq 0 ]; then
    echo "=========================================="
    echo "✓ Main content processed successfully!"
    echo "=========================================="
    
    # Process extras if any were found
    if [ ${#EXTRAS_FOUND[@]} -gt 0 ]; then
        echo ""
        echo "=========================================="
        echo "Processing Extras"
        echo "=========================================="
        
        # Try to detect the output path from FileBot output
        # Look for lines like: [MOVE] from [...] to [...]
        # Extract the show/movie name and season (for TV)
        
        # For TV shows, we need to find the Season folder that was created
        if [ "$TYPE" = "tv" ]; then
            # Extract show name and season from input path
            show_folder=$(basename "$(dirname "$INPUT_DIR")")
            season_folder=$(basename "$INPUT_DIR")
            
            # Try to find the created directory in library
            # FileBot renames, so we need to search for it
            target_base=$(find "$OUTPUT_DIR" -type d -maxdepth 1 2>/dev/null | head -1)
            if [ -n "$target_base" ]; then
                # Find the season directory
                target_extras=$(find "$OUTPUT_DIR" -type d -name "Season*" 2>/dev/null | grep -i "$(echo $season_folder | sed 's/[^0-9]*//g')" | head -1)
            fi
        else
            # For movies, find the movie directory
            target_extras=$(find "$OUTPUT_DIR" -type d -maxdepth 1 2>/dev/null | tail -1)
        fi
        
        # If we couldn't auto-detect, ask user
        if [ -z "$target_extras" ] || [ ! -d "$target_extras" ]; then
            echo ""
            echo "Could not auto-detect library destination."
            echo "Please enter the full path where extras should be copied:"
            echo "(This is where FileBot moved your files)"
            read -r target_extras
            
            if [ ! -d "$target_extras" ]; then
                echo "⚠️  Warning: Directory does not exist: $target_extras"
                echo "Extras will NOT be copied. You can copy them manually later."
                target_extras=""
            fi
        fi
        
        if [ -n "$target_extras" ]; then
            echo ""
            echo "Copying extras to: $target_extras"
            echo ""
            
            # Copy each extras directory
            for extra_info in "${EXTRAS_FOUND[@]}"; do
                IFS=':' read -r extra_type extra_count <<< "$extra_info"
                
                echo "→ Copying $extra_type/ ($extra_count files)..."
                
                # Create extras directory in library
                mkdir -p "$target_extras/$extra_type"
                
                # Copy files
                cp -v "$INPUT_DIR/$extra_type"/*.mkv "$target_extras/$extra_type/" 2>/dev/null || true
                
                # Verify copy
                copied_count=$(find "$target_extras/$extra_type" -type f -name "*.mkv" 2>/dev/null | wc -l)
                if [ $copied_count -eq $extra_count ]; then
                    echo "  ✓ $copied_count extras copied successfully"
                else
                    echo "  ⚠️  Warning: Expected $extra_count files, but found $copied_count"
                fi
            done
            
            echo ""
            echo "✓ Extras processing complete"
        fi
    fi
    
    echo ""
    echo "Files moved to library: $OUTPUT_DIR"
    echo ""
    
    # Check if input directory is now mostly empty (may have extras left)
    remaining_files=$(eval "find \"$INPUT_DIR\" -type f -name \"*.mkv\" $exclude_pattern" 2>/dev/null | wc -l)
    
    if [ $remaining_files -eq 0 ]; then
        echo "Main content successfully moved from source"
        
        if [ ${#EXTRAS_FOUND[@]} -eq 0 ]; then
            echo ""
            read -p "Delete empty directory structure? [Y/n]: " -r
            echo
            
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                rm -rf "$INPUT_DIR"
                echo "✓ Cleaned up: $INPUT_DIR"
            fi
        else
            echo ""
            echo "ℹ️  Source extras remain at: $INPUT_DIR"
            echo "You can delete them manually after verifying library extras:"
            echo "  rm -rf \"$INPUT_DIR\""
        fi
    else
        echo "⚠️  Warning: $remaining_files main file(s) remain in input"
        echo "These may have failed to process"
        echo "Check: $INPUT_DIR"
    fi
    
    echo ""
    echo "=========================================="
    echo "✓ Complete!"
    echo "=========================================="
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
