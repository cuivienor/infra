# Migrating Top-Tier Legacy Media to Library

**Goal**: Move top-quality legacy media to your main library with proper FileBot naming and organization.

**Date**: November 13, 2025  
**Target**: 30-35 files (~350-400GB)

---

## What We're Keeping

Based on your quality assessment, we're keeping only the **top-tier content** (Score 80+ and complete collections):

### Individual Films (Score 80+)
- **Birdman** (2014) - 15.60GB
- **Boyhood** (2014) - 16.50GB
- **Se7en** (1995) - 14.50GB
- **Indiana Jones: Raiders of the Lost Ark** (1981) - 9.19GB
- **Indiana Jones: Temple of Doom** (1984) - 9.39GB
- **Rocky** (1976) - 10.92GB
- **Rocky IV** (1985) - 10.11GB
- **Memento** (2000) - 10.93GB
- **Aliens** (1986) Director's Cut - 15.34GB
- **Spirited Away** (2001) - 10.13GB
- **The Usual Suspects** (1995) - 8.44GB

### Complete Collections

**Star Wars (6 films, ~90GB)**:
- Episode I: The Phantom Menace (1999)
- Episode II: Attack of the Clones (2002)
- Episode III: Revenge of the Sith (2005)
- Episode IV: A New Hope (1977)
- Episode V: The Empire Strikes Back (1980)
- Episode VI: Return of the Jedi (1983)

**Harry Potter (6 films, ~75GB)**:
- Philosopher's Stone (2001) Extended
- Chamber of Secrets (2002) Extended
- Prisoner of Azkaban (2004)
- Goblet of Fire (2005)
- Order of the Phoenix (2007)
- Half-Blood Prince (2009)
- ⚠️ Missing: Deathly Hallows Part 1 & 2

**Rocky Series (4 films, ~44GB)**:
- Rocky (1976)
- Rocky II (1979)
- Rocky III (1982)
- Rocky IV (1985)

**Bonus: Game of Thrones S01** (10 episodes, ~17GB):
- Complete Season 1 in HEVC 1080p

---

## Migration Process

### Overview

```
legacy-media/   →   staging/2-ready/   →   library/
   (raw)              (FileBot ready)        (organized)
```

### Step 1: Copy Files to Staging

**Script**: `scripts/media/migration/migrate-top-tier-to-library.sh`

**What it does**:
- Copies top-tier files from legacy-media to staging
- Organizes into movies/ and tv/ folders
- Preserves file ownership (media:media)
- Creates staging structure for FileBot processing

**Run on**: Analyzer container (CT303) or homelab host

```bash
# SSH to analyzer container
ssh root@192.168.1.73

# Run migration script
/home/media/scripts/migrate-top-tier-to-library.sh
```

**Output**:
- Movies → `/mnt/media/staging/2-ready/movies/`
- TV → `/mnt/media/staging/2-ready/tv/`

---

### Step 2: Organize with FileBot

**Script**: `scripts/media/migration/organize-legacy-with-filebot.sh`

**What it does**:
- Runs FileBot in DRY RUN mode first (preview changes)
- Shows you exactly what will be renamed/organized
- Prompts for confirmation before executing
- Moves files to library with proper naming:
  - Movies: `Movie Name (Year)/Movie Name (Year).mkv`
  - TV: `Show Name/Season 01/Show Name - S01E01 - Episode Title.mkv`

**Run on**: Analyzer container (CT303) - has FileBot installed

```bash
# SSH to analyzer
ssh root@192.168.1.73

# Run FileBot organization
/home/media/scripts/organize-legacy-with-filebot.sh
```

**Important**: Review the dry-run output carefully before confirming!

---

### Step 3: Verify in Jellyfin

1. **Check Jellyfin web interface**
   - Navigate to Libraries
   - New content should appear automatically
   - If not, run "Scan Library" manually

2. **Verify file structure**:
   ```bash
   # Check organized movies
   ls -R /mnt/media/library/movies/
   
   # Check organized TV
   ls -R /mnt/media/library/tv/
   ```

3. **Test playback** of a few files to ensure quality

---

### Step 4: Cleanup

Once you've verified everything works:

```bash
# Clean up staging area
rm -rf /mnt/media/staging/2-ready/movies/*
rm -rf /mnt/media/staging/2-ready/tv/*

# Optional: Delete legacy-media directory later
# (Keep for now in case you want to review other files)
```

---

## What Happens to Other Files?

**Files NOT being migrated** remain in `/mnt/storage/media/legacy-media`:

- **MAYBE quality (10 files, ~46.5GB)**: Review individually later
- **Low quality (7 files, ~17GB)**: Delete when ready
- **Collections with lower scores**: Star Wars/Harry Potter films with scores 60-75

These stay in `legacy-media` for you to review and decide later.

---

## Expected Results

### Library Structure After Migration

```
/mnt/media/library/
├── movies/
│   ├── Aliens (1986)/
│   │   └── Aliens (1986).mkv
│   ├── Birdman (2014)/
│   │   └── Birdman (2014).mkv
│   ├── Harry Potter and the Chamber of Secrets (2002)/
│   │   └── Harry Potter and the Chamber of Secrets (2002).mkv
│   ├── Indiana Jones and the Raiders of the Lost Ark (1981)/
│   │   └── Indiana Jones and the Raiders of the Lost Ark (1981).mkv
│   ├── Rocky (1976)/
│   │   └── Rocky (1976).mkv
│   ├── Star Wars Episode IV - A New Hope (1977)/
│   │   └── Star Wars Episode IV - A New Hope (1977).mkv
│   └── ... (all other movies)
│
└── tv/
    └── Game of Thrones/
        └── Season 01/
            ├── Game of Thrones - S01E01 - Winter Is Coming.mkv
            ├── Game of Thrones - S01E02 - The Kingsroad.mkv
            └── ... (all episodes)
```

### Space Usage

- **Library**: +350-400GB (top-tier content)
- **Legacy-media**: -350GB (files moved out)
- **Net change**: None (files moved, not duplicated)

---

## FileBot Details

### Why FileBot?

FileBot provides:
1. **Proper naming**: Matches TheMovieDB/TheTVDB standards
2. **Metadata accuracy**: Correct titles, years, episode numbers
3. **Jellyfin compatibility**: Plex/Jellyfin naming conventions
4. **Automatic organization**: Creates proper folder structure

### FileBot Formats Used

**Movies**:
```
Format: {n} ({y})/{n} ({y})
Example: Birdman (2014)/Birdman (2014).mkv
```

**TV Shows**:
```
Format: {n}/Season {s.pad(2)}/{n} - {s00e00} - {t}
Example: Game of Thrones/Season 01/Game of Thrones - S01E01 - Winter Is Coming.mkv
```

### Handling Ambiguous Matches

If FileBot can't auto-match a file:

1. **Interactive mode**: FileBot will show options
2. **Manual query**: You can specify the exact title/year
3. **Skip**: You can skip problematic files and handle manually

For most files (especially your well-named legacy files), FileBot should auto-match perfectly.

---

## Troubleshooting

### FileBot Can't Find a Movie

**Symptoms**: "No matches found" or multiple ambiguous results

**Solutions**:
1. Check the file name - is it clear what movie it is?
2. Manually search TheMovieDB for the exact title
3. Use FileBot's interactive mode to select correct match
4. Verify the movie exists in TheMovieDB database

### File Not Moving

**Symptoms**: File remains in staging after FileBot runs

**Possible causes**:
- FileBot couldn't match the file
- Permissions issue (wrong owner)
- File already exists in library

**Check**:
```bash
# Check FileBot output for errors
# Check file ownership
ls -lah /mnt/media/staging/2-ready/movies/

# Ensure files owned by media:media
chown -R media:media /mnt/media/staging/2-ready/
```

### Missing Episodes in TV Shows

**Symptoms**: Some Game of Thrones episodes not processed

**Cause**: Usually file naming doesn't match expected pattern

**Solution**: Check episode file names match pattern:
```
Game of Thrones - S01E01 - Title.mkv
```

If they're named differently, FileBot may need help matching them.

---

## Advanced: Manual FileBot Commands

If you want more control, use FileBot directly:

### Process Individual Movie
```bash
filebot -rename "/mnt/media/staging/2-ready/movies/movie_file.mkv" \
  --db TheMovieDB \
  --q "Movie Name 2014" \
  --output /mnt/media/library \
  --format '{n} ({y})/{n} ({y})' \
  --action move
```

### Process TV Show Season
```bash
filebot -rename "/mnt/media/staging/2-ready/tv/" \
  --db TheTVDB \
  --q "Game of Thrones" \
  --output /mnt/media/library \
  --format '{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}' \
  --action move
```

### Test Mode (No Changes)
Add `--action test` instead of `--action move` to preview changes.

---

## Summary

### What You're Getting

✅ **~30-35 high-quality films** in proper library organization  
✅ **6 Star Wars films** (original + prequel trilogies)  
✅ **6 Harry Potter films** (missing last 2)  
✅ **4 Rocky films** (complete series I-IV)  
✅ **Game of Thrones S01** (complete season, HEVC 1080p)  
✅ **Proper Jellyfin-compatible naming** and structure  
✅ **No quality loss** - files moved as-is  

### What Stays in Legacy

⚠️ **10 "MAYBE" files** - for later review  
❌ **7 low-quality files** - delete when ready  
📦 **Other collections** - lower quality versions

### Time Estimate

- **Migration script**: 5-10 minutes (copying ~400GB)
- **FileBot organization**: 2-5 minutes (moving + renaming)
- **Verification**: 5-10 minutes
- **Total**: 15-25 minutes

---

## Quick Start

```bash
# 1. SSH to analyzer
ssh root@192.168.1.73

# 2. Run migration (copy files to staging)
/home/media/scripts/migrate-top-tier-to-library.sh

# 3. Run FileBot organization
/home/media/scripts/organize-legacy-with-filebot.sh

# 4. Verify in Jellyfin
# Browse to your Jellyfin web interface

# 5. Clean up staging
rm -rf /mnt/media/staging/2-ready/movies/*
rm -rf /mnt/media/staging/2-ready/tv/*
```

That's it! You now have a curated, properly organized library of your best content!
