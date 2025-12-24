#!/bin/bash
# FileBot Media Organizer
# Usage: ./filebot.sh -t <type> -n <name> [-s <season>] [--preview] [--id <db_id>]
#
# Examples:
#   ./filebot.sh -t movie -n "The Lion King"
#   ./filebot.sh -t show -n "Avatar The Last Airbender" -s 2
#   ./filebot.sh -t show -n "Cosmos A Spacetime Odyssey" -s 1 --preview
#   ./filebot.sh -t show -n "Avatar" -s 2 --id 74852
#
# State Management:
#   - Creates .filebot/ directory with status, logs, and metadata
#   - Status: completed or failed
#   - Tracks what files were copied to library
#
# Workflow:
#   1. Run with --preview first to verify matching
#   2. If matching is wrong, use --id to specify exact database ID
#   3. Run without --preview to execute (will prompt for confirmation)

set -e

# Default values
TYPE=""
NAME=""
SEASON=""
PREVIEW_ONLY=0
DB_ID=""

# Standardized media path
MEDIA_BASE="/mnt/media"

# Help function
show_help() {
    cat << EOF
Usage: $0 -t <type> -n <name> [-s <season>] [--preview] [--id <db_id>]

Options:
  -t, --type <type>       Media type: 'movie' or 'show' (required)
  -n, --name <name>       Title of the movie or show (required)
  -s, --season <number>   Season number (required for shows)
  --preview               Preview only (dry-run), don't execute
  --id <db_id>            Force specific database ID for matching
  -h, --help              Show this help message

Examples:
  $0 -t movie -n "The Lion King"
  $0 -t show -n "Avatar The Last Airbender" -s 2
  $0 -t show -n "Cosmos A Spacetime Odyssey" -s 1 --preview
  $0 --type show --name "Avatar" --season 2 --id 74852

State Management:
  Job state is tracked in INPUT_DIR/.filebot/
  Copies files to library (preserves source for manual cleanup)

Workflow:
  1. Run with --preview to see what FileBot will do
  2. If wrong match, note the correct ID from output and use --id
  3. Run without --preview to execute (prompts for confirmation)
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
        --preview)
            PREVIEW_ONLY=1
            shift
            ;;
        --id)
            DB_ID="$2"
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

# Check if filebot is installed
if ! command -v filebot &> /dev/null; then
    echo "Error: FileBot is not installed"
    exit 1
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
        INPUT_DIR="${MEDIA_BASE}/staging/3-transcoded/movies/${SAFE_NAME}"
        LIBRARY_BASE="${MEDIA_BASE}/library/movies"
        DB="TheMovieDB"
        FORMAT='{n} ({y})/{n} ({y})'
        DISPLAY_INFO="Movie: $NAME"
        ;;
    show)
        SEASON_DIR=$(printf "Season_%02d" "$SEASON")
        INPUT_DIR="${MEDIA_BASE}/staging/3-transcoded/tv/${SAFE_NAME}/${SEASON_DIR}"
        LIBRARY_BASE="${MEDIA_BASE}/library/tv"
        DB="TheTVDB"
        FORMAT='{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}'
        DISPLAY_INFO="Show: $NAME | Season: $SEASON"
        ;;
esac

# Verify input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Input directory not found: $INPUT_DIR"
    exit 1
fi

# State management directory
STATE_DIR="$INPUT_DIR/.filebot"
mkdir -p "$STATE_DIR"

LOG_FILE="$STATE_DIR/filebot.log"
STATUS_FILE="$STATE_DIR/status"
METADATA_FILE="$STATE_DIR/metadata.json"
COPIED_FILE="$STATE_DIR/copied.txt"
STARTED_FILE="$STATE_DIR/started_at"
COMPLETED_AT_FILE="$STATE_DIR/completed_at"

# Jellyfin-supported extras types
EXTRAS_TYPES=("behind the scenes" "deleted scenes" "featurettes" "interviews" "scenes" "shorts" "trailers" "other")

# Find extras in input directory
declare -a EXTRAS_FOUND
for extras_type in "${EXTRAS_TYPES[@]}"; do
    if [ -d "$INPUT_DIR/$extras_type" ]; then
        extras_count=$(find "$INPUT_DIR/$extras_type" -type f -name "*.mkv" 2>/dev/null | wc -l)
        if [ $extras_count -gt 0 ]; then
            EXTRAS_FOUND+=("$extras_type:$extras_count")
        fi
    fi
done

# Count main content files (exclude extras and state directories)
main_file_count=0
# shellcheck disable=SC2034
while IFS= read -r -d '' _file; do
    main_file_count=$((main_file_count + 1))
done < <(find "$INPUT_DIR" -maxdepth 1 -name "*.mkv" -type f -print0)

echo "=========================================="
echo "FileBot Media Organizer"
echo "=========================================="
echo "$DISPLAY_INFO"
echo ""
echo "Input: $INPUT_DIR"
echo "Library: $LIBRARY_BASE"
echo "Database: $DB"
if [ -n "$DB_ID" ]; then
    echo "Forced ID: $DB_ID"
fi
echo ""
echo "Main content: $main_file_count file(s)"

if [ ${#EXTRAS_FOUND[@]} -gt 0 ]; then
    echo "Extras:"
    for extra_info in "${EXTRAS_FOUND[@]}"; do
        IFS=':' read -r extra_type extra_count <<< "$extra_info"
        echo "  - $extra_type/ ($extra_count files)"
    done
fi
echo "=========================================="
echo ""

if [ $main_file_count -eq 0 ]; then
    echo "Error: No main content MKV files found in $INPUT_DIR"
    exit 1
fi

# Build FileBot command
# Note: Do NOT use -r (recursive) - we only want to process top-level files
# Extras are copied separately by this script
FILEBOT_ARGS=(-rename "$INPUT_DIR" --db "$DB" --output "$LIBRARY_BASE" --format "$FORMAT" -non-strict)

# Add query/filter if specified
if [ -n "$DB_ID" ]; then
    FILEBOT_ARGS+=(--filter "id == $DB_ID")
elif [ -n "$NAME" ]; then
    FILEBOT_ARGS+=(--q "$NAME")
fi

# Run preview
echo "Running FileBot preview..."
echo ""
echo "=========================================="

FILEBOT_ARGS_TEST=("${FILEBOT_ARGS[@]}" --action test)
filebot_test_output=$(filebot "${FILEBOT_ARGS_TEST[@]}" 2>&1) || true

echo "$filebot_test_output"
echo "=========================================="
echo ""

# Check if any files were matched
if ! echo "$filebot_test_output" | grep -q '\[TEST\]'; then
    echo "✗ FileBot failed to match files"
    echo ""
    echo "Suggestions:"
    echo "  - Check the database IDs shown above"
    echo "  - Use --id <number> to force a specific match"
    echo "  - Verify the series/movie name is correct"
    exit 1
fi

# Extract where files will go (for extras copying)
target_path=$(echo "$filebot_test_output" | grep -oP '\[TEST\] from .* to \[\K[^\]]+' | head -1)
if [ -n "$target_path" ]; then
    LIBRARY_DEST=$(dirname "$target_path")
    echo "Main content will be copied to: $LIBRARY_DEST"
else
    echo "Warning: Could not determine library destination from preview"
    LIBRARY_DEST=""
fi

# Show extras preview
if [ ${#EXTRAS_FOUND[@]} -gt 0 ] && [ -n "$LIBRARY_DEST" ]; then
    echo ""
    echo "Extras will be copied to:"
    for extra_info in "${EXTRAS_FOUND[@]}"; do
        IFS=':' read -r extra_type extra_count <<< "$extra_info"
        echo "  $LIBRARY_DEST/$extra_type/ ($extra_count files)"
    done
fi
echo ""

# If preview only, stop here
if [ $PREVIEW_ONLY -eq 1 ]; then
    echo "Preview complete (no changes made)"
    echo ""
    echo "To execute, run without --preview:"
    echo "  $0 -t $TYPE -n \"$NAME\"${SEASON:+ -s $SEASON}"
    exit 0
fi

# Confirm execution
read -p "Execute this copy operation? [y/N]: " -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted - no changes made"
    exit 0
fi

# Initialize state
echo "in_progress" > "$STATUS_FILE"
date -Iseconds > "$STARTED_FILE"

# Save metadata
cat > "$METADATA_FILE" << EOF
{
  "type": "$TYPE",
  "name": "$NAME",
  "safe_name": "$SAFE_NAME",
  "season": "$SEASON",
  "database": "$DB",
  "database_id": "$DB_ID",
  "input_dir": "$INPUT_DIR",
  "library_base": "$LIBRARY_BASE",
  "started_at": "$(cat "$STARTED_FILE")"
}
EOF

# Start logging
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=========================================="
echo "Executing FileBot Copy"
echo "=========================================="
echo "Started: $(date)"
echo ""

# Execute FileBot with copy action
FILEBOT_ARGS_EXEC=("${FILEBOT_ARGS[@]}" --action copy)
filebot_output=$(filebot "${FILEBOT_ARGS_EXEC[@]}" 2>&1) || true

echo "$filebot_output"
echo ""

# Check results
copied_count=$(echo "$filebot_output" | grep -c '\[COPY\]' || echo 0)

if [ $copied_count -gt 0 ]; then
    echo "✓ Successfully copied $copied_count main file(s)"

    # Extract actual library destination
    actual_dest=$(echo "$filebot_output" | grep -oP '\[COPY\] from .* to \[\K[^\]]+' | head -1)
    if [ -n "$actual_dest" ]; then
        LIBRARY_DEST=$(dirname "$actual_dest")
    fi

    # Log copied files
    echo "$filebot_output" | grep '\[COPY\]' > "$COPIED_FILE"

    # Copy extras if any were found
    if [ ${#EXTRAS_FOUND[@]} -gt 0 ] && [ -n "$LIBRARY_DEST" ]; then
        echo ""
        echo "=========================================="
        echo "Copying Extras to Library"
        echo "=========================================="

        extras_success=0
        extras_total=0

        for extra_info in "${EXTRAS_FOUND[@]}"; do
            IFS=':' read -r extra_type extra_count <<< "$extra_info"
            extras_total=$((extras_total + extra_count))

            echo "→ Copying $extra_type/ ($extra_count files)..."

            # Create extras directory in library
            mkdir -p "$LIBRARY_DEST/$extra_type"

            # Copy files
            if cp -v "$INPUT_DIR/$extra_type"/*.mkv "$LIBRARY_DEST/$extra_type/" 2>/dev/null; then
                # Verify copy
                copied_extras=$(find "$LIBRARY_DEST/$extra_type" -type f -name "*.mkv" 2>/dev/null | wc -l)
                if [ $copied_extras -eq $extra_count ]; then
                    echo "  ✓ $copied_extras files copied"
                    extras_success=$((extras_success + copied_extras))
                    # Log to copied file
                    find "$LIBRARY_DEST/$extra_type" -type f -name "*.mkv" >> "$COPIED_FILE"
                else
                    echo "  ⚠️  Expected $extra_count files, found $copied_extras"
                fi
            else
                echo "  ✗ Failed to copy $extra_type"
            fi
        done

        echo ""
        echo "✓ Extras: $extras_success/$extras_total files copied"
    fi

    # Calculate total size
    total_copied=0
    if [ -f "$COPIED_FILE" ]; then
        while IFS= read -r line; do
            # Extract file path from [COPY] line or direct path
            if [[ "$line" =~ \[COPY\].*to\ \[([^\]]+)\] ]]; then
                file_path="${BASH_REMATCH[1]}"
            else
                file_path="$line"
            fi
            if [ -f "$file_path" ]; then
                file_size=$(stat -c%s "$file_path" 2>/dev/null || echo 0)
                total_copied=$((total_copied + file_size))
            fi
        done < "$COPIED_FILE"
    fi

    if [ $total_copied -gt 0 ]; then
        total_gb=$(awk "BEGIN {printf \"%.2f\", $total_copied/1024/1024/1024}")
        echo ""
        echo "Total copied: ${total_gb}GB"
    fi

    echo ""
    echo "=========================================="
    echo "Summary"
    echo "=========================================="
    echo "Library destination: $LIBRARY_DEST"
    echo "Main content: $copied_count file(s) copied"
    if [ ${#EXTRAS_FOUND[@]} -gt 0 ]; then
        echo "Extras: $extras_success file(s) copied"
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Verify files in Jellyfin"
    echo "  2. Run Jellyfin library scan if needed"
    echo "  3. Clean up source when satisfied:"
    echo "     rm -rf \"$INPUT_DIR\""
    echo ""

    # Update state
    echo "completed" > "$STATUS_FILE"
    date -Iseconds > "$COMPLETED_AT_FILE"

    echo "=========================================="
    echo "✓ FileBot processing complete"
    echo "=========================================="
else
    echo "✗ FileBot failed to copy files"
    echo ""
    echo "Check log: $LOG_FILE"

    # Update state
    echo "failed" > "$STATUS_FILE"
    date -Iseconds > "$COMPLETED_AT_FILE"

    exit 1
fi
