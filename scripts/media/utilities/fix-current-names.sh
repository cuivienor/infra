#!/bin/bash
# fix-current-names.sh - Add disc identifiers to files already in 1-ripped
#
# This fixes the duplicate filename issue for Jellyfin scanning

set -e

STAGING_BASE="/mnt/storage/media/staging"

echo "=========================================="
echo "Fix Filenames in 1-ripped"
echo "=========================================="
echo ""
echo "This will rename files in 1-ripped/tv/ folders"
echo "to include disc identifiers (avoiding duplicate names)"
echo ""
echo "Changes:"
echo "  Cosmos: All discs will get Disc# identifier"
echo "    Title_t00.mkv → Cosmos_A_Spacetime_Odyssey_Disc1_t00.mkv"
echo ""
echo "  Avatar: All discs will get Disc# identifier"
echo "    Avatar_The_Last_Airbender_t00.mkv → Avatar_The_Last_Airbender_Disc1_t00.mkv"
echo ""
echo "=========================================="
read -p "Proceed with renaming? [y/N]: " -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 0
fi

echo ""
echo "Starting rename..."
echo ""

# ============================================
# Fix Cosmos in 1-ripped/tv/
# ============================================

COSMOS_DIR="$STAGING_BASE/1-ripped/tv/Cosmos_A_Spacetime_Odyssey"

if [ -d "$COSMOS_DIR" ]; then
    echo "1. Fixing Cosmos filenames..."

    # Process each disc folder
    for disc_folder in "$COSMOS_DIR"/S01_Disc*; do
        if [ -d "$disc_folder" ]; then
            # Extract disc number from folder name (S01_Disc1_2024-11-10 → 1)
            disc_num=$(basename "$disc_folder" | grep -oP 'Disc\K[0-9]+')

            echo "  → Disc ${disc_num}: $(basename "$disc_folder")"

            cd "$disc_folder"

            # Rename files to include disc identifier
            for file in *.mkv; do
                if [ -f "$file" ]; then
                    # Check if already has disc identifier
                    if [[ "$file" =~ Cosmos_A_Spacetime_Odyssey_Disc[0-9]+_t[0-9]+\.mkv ]]; then
                        echo "    ✓ Already correct: $file"
                    else
                        # Extract track number
                        if [[ "$file" =~ _t([0-9]+)\.mkv ]] || [[ "$file" =~ t([0-9]+)\.mkv ]]; then
                            track_num="${BASH_REMATCH[1]}"
                            new_name="Cosmos_A_Spacetime_Odyssey_Disc${disc_num}_t${track_num}.mkv"

                            if [ "$file" != "$new_name" ]; then
                                mv "$file" "$new_name"
                                echo "    ✓ $file → $new_name"
                            fi
                        fi
                    fi
                fi
            done

            cd - > /dev/null
        fi
    done

    echo ""
else
    echo "1. Cosmos folder not found at: $COSMOS_DIR"
    echo ""
fi

# ============================================
# Fix Avatar in 1-ripped/tv/
# ============================================

AVATAR_DIR="$STAGING_BASE/1-ripped/tv/Avatar_The_Last_Airbender"

if [ -d "$AVATAR_DIR" ]; then
    echo "2. Fixing Avatar filenames..."

    # Process each disc folder
    for disc_folder in "$AVATAR_DIR"/S01_Disc*; do
        if [ -d "$disc_folder" ]; then
            # Extract disc number from folder name (S01_Disc1_2024-11-10 → 1)
            disc_num=$(basename "$disc_folder" | grep -oP 'Disc\K[0-9]+')

            echo "  → Disc ${disc_num}: $(basename "$disc_folder")"

            cd "$disc_folder"

            # Rename files to include disc identifier
            for file in *.mkv; do
                if [ -f "$file" ]; then
                    # Check if already has disc identifier
                    if [[ "$file" =~ Avatar_The_Last_Airbender_Disc[0-9]+_t[0-9]+\.mkv ]]; then
                        echo "    ✓ Already correct: $file"
                    else
                        # Extract track number from various formats
                        track_num=""

                        # Format: Avatar_The_Last_Airbender_t00.mkv
                        if [[ "$file" =~ Avatar_The_Last_Airbender_t([0-9]+)\.mkv ]]; then
                            track_num="${BASH_REMATCH[1]}"
                        # Format: S01E01.mkv (convert episode to track)
                        elif [[ "$file" =~ S01E([0-9]+)\.mkv ]]; then
                            ep_num="${BASH_REMATCH[1]}"
                            track_num=$((10#$ep_num - 1))
                            track_num=$(printf "%02d" $track_num)
                        # Generic format: anything_t00.mkv
                        elif [[ "$file" =~ _t([0-9]+)\.mkv ]] || [[ "$file" =~ t([0-9]+)\.mkv ]]; then
                            track_num="${BASH_REMATCH[1]}"
                        fi

                        if [ -n "$track_num" ]; then
                            new_name="Avatar_The_Last_Airbender_Disc${disc_num}_t${track_num}.mkv"

                            if [ "$file" != "$new_name" ]; then
                                mv "$file" "$new_name"
                                echo "    ✓ $file → $new_name"
                            fi
                        else
                            echo "    ⚠ Could not parse: $file"
                        fi
                    fi
                fi
            done

            cd - > /dev/null
        fi
    done

    echo ""
else
    echo "2. Avatar folder not found at: $AVATAR_DIR"
    echo ""
fi

echo "=========================================="
echo "✓ Rename Complete!"
echo "=========================================="
echo ""
echo "All files now have unique names with disc identifiers."
echo "Jellyfin will no longer see duplicate filenames when scanning 1-ripped."
echo ""
echo "You can now add the Jellyfin library pointing to:"
echo "  /mnt/storage/media/staging/1-ripped"
echo ""
