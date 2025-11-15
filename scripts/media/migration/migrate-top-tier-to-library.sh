#!/bin/bash
#
# shellcheck disable=SC2155,SC2034
# migrate-top-tier-to-library.sh
# Migrates top-tier legacy media to library for FileBot processing
#
# Top tier criteria:
# - Score 80+ (excellent bitrate, codec, audio)
# - OR Complete collections (Star Wars, Harry Potter, Rocky)
# - Bitrate preference: 10000+ kbps for movies
#

set -euo pipefail

# Paths
LEGACY_DIR="/mnt/media/legacy-media"
STAGING_DIR="/mnt/media/staging/2-ready"  # FileBot will process from here
LIBRARY_DIR="/mnt/media/library"

# Create staging directory if needed
mkdir -p "$STAGING_DIR/movies"
mkdir -p "$STAGING_DIR/tv"

echo "================================================"
echo "Migrating Top-Tier Legacy Media to Library"
echo "================================================"
echo ""
echo "Source: $LEGACY_DIR"
echo "Staging: $STAGING_DIR (for FileBot processing)"
echo "Final: $LIBRARY_DIR"
echo ""

# Function to copy file and preserve structure
migrate_file() {
    local src="$1"
    local type="$2"  # movies or tv
    local basename=$(basename "$src")
    local dest="$STAGING_DIR/$type/$basename"

    if [ -f "$src" ]; then
        echo "  Copying: $basename"
        cp "$src" "$dest"
        chown media:media "$dest"
    else
        echo "  WARNING: File not found: $src"
    fi
}

echo "=== Top Individual Films (Score 80+) ==="
echo ""

# Birdman (2014)
migrate_file "$LEGACY_DIR/Movies/Birdman (2014)/Birdman (2014).mkv" "movies"

# Boyhood (2014)
migrate_file "$LEGACY_DIR/Movies/Boyhood (2014)/Boyhood (2014).mkv" "movies"

# Se7en (1995)
migrate_file "$LEGACY_DIR/Movies/Se7en.1995.1080p.BluRay.DTS.x264-CyTSuNee/Se7en.1995.1080p.NL/Se7en.1995.1080p.BluRay.DTS.x264-CyTSuNee/Se7en.1995.1080p.BluRay.DTS.x264-CyTSuNee.mkv" "movies"

# Indiana Jones: Raiders of the Lost Ark (1981)
migrate_file "$LEGACY_DIR/Movies/1080p/Indiana.Jones.and.the.Raiders.of.the.Lost.Ark.1981.1080p.BluRay.x264-BARC0DE/Indiana.Jones.and.the.Raiders.of.the.Lost.Ark.1981.1080p.BluRay.x264-BARC0DE.mkv" "movies"

# Indiana Jones: Temple of Doom (1984)
migrate_file "$LEGACY_DIR/Movies/1080p/Indiana.Jones.and.the.Temple.of.Doom.1984.1080p.BluRay.x264-BARC0DE/Indiana.Jones.and.the.Temple.of.Doom.1984.1080p.BluRay.x264-BARC0DE.mkv" "movies"

# Rocky (1976)
migrate_file "$LEGACY_DIR/Movies/Rocky (1976)/Rocky (1976).mkv" "movies"

# Memento (2000)
migrate_file "$LEGACY_DIR/Movies/Memento.2000.1080p.BluRay.x264-HDMI/memento.2000.1080p.bluray.x264-hdmi.mkv" "movies"

# Aliens (1986) Director's Cut
migrate_file "$LEGACY_DIR/old-downloads/Aliens.1986.Directors.Cut.iNTERNAL.CRF.1080p.BluRay.x264-MOOVEE/Aliens.1986.Directors.Cut.iNTERNAL.CRF.1080p.BluRay.x264-MOOVEE.mkv" "movies"

# Spirited Away (2001)
migrate_file "$LEGACY_DIR/old-downloads/Spirited.Away.2001.1080p.BluRay.DTS.x264-CyTSuNee/Spirited.Away.2001.1080p.BluRay.DTS.x264-CyTSuNee.mkv" "movies"

# The Usual Suspects (1995)
migrate_file "$LEGACY_DIR/Movies/The.Usual.Suspects.1995.1080p.Bluray.X264/The.Usual.Suspects.1995.1080p.Bluray.X264.mkv" "movies"

echo ""
echo "=== Star Wars Collection (Original + Prequel Trilogy) ==="
echo ""

# Original Trilogy
migrate_file "$LEGACY_DIR/Movies/Star Wars Episode IV A New Hope (1977)/Star Wars Episode IV A New Hope (1977).mkv" "movies"
migrate_file "$LEGACY_DIR/Movies/Star Wars Episode V The Empire Strikes Back (1980)/Star Wars Episode V The Empire Strikes Back (1980).mkv" "movies"
migrate_file "$LEGACY_DIR/Movies/Star Wars Episode VI Return of the Jedi (1983)/Star Wars Episode VI Return of the Jedi (1983).mkv" "movies"

# Prequel Trilogy
migrate_file "$LEGACY_DIR/Movies/Star Wars Episode I The Phantom Menace (1999)/Star Wars Episode I The Phantom Menace (1999).mkv" "movies"
migrate_file "$LEGACY_DIR/Movies/SW2 1080p/SW2 1080p.mkv" "movies"  # Episode II
migrate_file "$LEGACY_DIR/Movies/SW3 1080p/SW3 1080p.mkv" "movies"  # Episode III

echo ""
echo "=== Harry Potter Collection (Complete Series) ==="
echo ""

# Philosopher's Stone (1)
migrate_file "$LEGACY_DIR/Movies/Harry.Potter.And.The.Philosophers.Stone.2001.Extended.MULTi.1080p.Bluray.x264-FHD/fhd-hp1ex1080p.mkv" "movies"

# Chamber of Secrets (2)
migrate_file "$LEGACY_DIR/Movies/Harry.Potter.And.The.Chamber.Of.Secrets.2002.EXTENDED.REPACK.1080p.BluRay.x264-SECTOR7/sector7-hp.chamber.of.secrets.extended.rp-x264.mkv" "movies"

# Prisoner of Azkaban (3)
migrate_file "$LEGACY_DIR/Movies/Harry.Potter.3.And.The.Prisoner.Of.Azkaban.2004.1080p.BluRay.DTS.x264-CyTSuNee/Harry.Potter.3.and.the.Prisoner.of.Azkaban.2004.1080p.BluRay.DTS.x264-CyTSuNee.mkv" "movies"

# Goblet of Fire (4)
migrate_file "$LEGACY_DIR/Movies/Harry.Potter.4.And.The.Goblet.Of.Fire.2005.1080p.BluRay.DTS.x264-CyTSuNee/Harry.Potter.4.and.the.Goblet.of.Fire.2005.1080p.BluRay.DTS.x264-CyTSuNee.mkv" "movies"

# Order of the Phoenix (5)
migrate_file "$LEGACY_DIR/Movies/Harry.Potter.and.the.Order.of.the.Phoenix.2007.PROPER.1080p.BluRay.x264-PHOBOS/Harry.Potter.and.the.Order.of.the.Phoenix.2007.PROPER.1080p.BluRay.x264-PHOBOS.mkv" "movies"

# Half-Blood Prince (6)
migrate_file "$LEGACY_DIR/Movies/Harry.Potter.And.The.Half.Blood.Prince.REPACK.1080p.BluRay.x264-METiS/m-hp-rpk-1080p.mkv" "movies"

# Note: Deathly Hallows Part 1 & 2 not found in legacy library
echo "  WARNING: Harry Potter 7 & 8 (Deathly Hallows) not found in legacy library"

echo ""
echo "=== Rocky Collection ==="
echo ""

migrate_file "$LEGACY_DIR/Movies/Rocky (1976)/Rocky (1976).mkv" "movies"  # Already copied above
migrate_file "$LEGACY_DIR/Movies/Rocky 2 (1979)/Rocky 2 (1979).mkv" "movies"
migrate_file "$LEGACY_DIR/Movies/Rocky III (1982)/Rocky III (1982).mkv" "movies"
migrate_file "$LEGACY_DIR/Movies/Rocky IV (1985)/Rocky IV (1985).mkv" "movies"

echo ""
echo "=== Bonus: Game of Thrones S01 (HEVC 1080p) ==="
echo ""

# Copy all Game of Thrones S01 episodes
if [ -d "$LEGACY_DIR/old-downloads/Game Of Thrones S01" ]; then
    echo "  Copying Game of Thrones Season 1..."
    find "$LEGACY_DIR/old-downloads/Game Of Thrones S01" -name "*.mkv" -type f | while read -r episode; do
        ep_basename=$(basename "$episode")
        echo "    - $ep_basename"
        cp "$episode" "$STAGING_DIR/tv/"
        chown media:media "$STAGING_DIR/tv/$ep_basename"
    done
else
    echo "  WARNING: Game of Thrones S01 directory not found"
fi

echo ""
echo "================================================"
echo "Migration Summary"
echo "================================================"
echo ""

movie_count=$(find "$STAGING_DIR/movies" -name "*.mkv" -type f 2>/dev/null | wc -l)
tv_count=$(find "$STAGING_DIR/tv" -name "*.mkv" -type f 2>/dev/null | wc -l)
total_size=$(du -sh "$STAGING_DIR" 2>/dev/null | cut -f1)

echo "Files copied to staging:"
echo "  Movies: $movie_count files"
echo "  TV: $tv_count files"
echo "  Total size: $total_size"
echo ""
echo "Next steps:"
echo "  1. Review files in: $STAGING_DIR"
echo "  2. Run FileBot to organize and rename properly"
echo "  3. FileBot will move files to: $LIBRARY_DIR"
echo ""
echo "FileBot command suggestion:"
echo "  filebot -rename $STAGING_DIR/movies --db TheMovieDB --format '{plex}' --action move --output $LIBRARY_DIR"
echo "  filebot -rename $STAGING_DIR/tv --db TheTVDB --format '{plex}' --action move --output $LIBRARY_DIR"
echo ""
echo "Or use the organize scripts:"
echo "  ~/scripts/organize-and-remux-movie.sh $STAGING_DIR/movies/<file>"
echo ""
