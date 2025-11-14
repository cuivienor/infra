# Legacy Media Migration - Quick Reference

**Goal**: Move top-tier legacy media (~30-35 files, ~400GB) to properly organized library

---

## Quick Start

```bash
# 1. SSH to analyzer container
ssh root@192.168.1.73

# 2. Copy files to staging (as media user)
su - media
~/scripts/migrate-top-tier-to-library.sh

# 3. Organize with FileBot (review dry-run first!)
~/scripts/organize-legacy-with-filebot.sh

# 4. Verify in Jellyfin, then clean up
rm -rf /mnt/media/staging/2-ready/movies/*
rm -rf /mnt/media/staging/2-ready/tv/*
```

---

## What's Being Migrated

### Movies (~25 files, ~280GB)
- **Individual films**: Birdman, Boyhood, Se7en, Memento, Aliens, Spirited Away, etc.
- **Star Wars**: Episodes I-VI (original + prequel trilogy)
- **Harry Potter**: 6 films (missing Deathly Hallows 1&2)
- **Rocky**: Rocky I-IV
- **Indiana Jones**: Raiders, Temple of Doom

### TV (~10 files, ~17GB)
- **Game of Thrones**: Season 1 (complete, HEVC 1080p)

---

## File Locations

| Stage | Path | Description |
|-------|------|-------------|
| **Source** | `/mnt/media/legacy-media/` | Original legacy files |
| **Staging** | `/mnt/media/staging/2-ready/` | Temporary (FileBot input) |
| **Library** | `/mnt/media/library/` | Final organized location |

---

## Scripts

### migrate-top-tier-to-library.sh
**Location**: `/home/media/scripts/` (on CT303)

**What it does**:
- Copies top-tier files from legacy-media to staging
- Organizes into movies/ and tv/ subdirectories
- Prepares for FileBot processing

**Run as**: `media` user

**Runtime**: ~5-10 minutes (400GB copy)

---

### organize-legacy-with-filebot.sh
**Location**: `/home/media/scripts/` (on CT303)

**What it does**:
- Runs FileBot DRY RUN first (preview)
- Prompts for confirmation
- Renames and moves to library with proper structure
- Uses TheMovieDB for movies, TheTVDB for TV

**Run as**: `media` user

**Runtime**: ~2-5 minutes

---

## Expected Library Structure

```
/mnt/media/library/
├── movies/
│   ├── Aliens (1986)/
│   │   └── Aliens (1986).mkv
│   ├── Birdman (2014)/
│   │   └── Birdman (2014).mkv
│   ├── Harry Potter and the Chamber of Secrets (2002)/
│   │   └── Harry Potter and the Chamber of Secrets (2002).mkv
│   ├── Star Wars Episode IV - A New Hope (1977)/
│   │   └── Star Wars Episode IV - A New Hope (1977).mkv
│   └── ...
└── tv/
    └── Game of Thrones/
        └── Season 01/
            ├── Game of Thrones - S01E01 - Winter Is Coming.mkv
            └── ...
```

---

## Troubleshooting

### FileBot can't match a file
- Check file name is clear
- Manually search TheMovieDB/TheTVDB
- Use FileBot interactive mode

### Files not moving
```bash
# Check ownership
ls -lah /mnt/media/staging/2-ready/movies/

# Fix if needed
chown -R media:media /mnt/media/staging/2-ready/
```

### Re-run FileBot only
```bash
# Movies
filebot -rename /mnt/media/staging/2-ready/movies \
  --db TheMovieDB \
  --output /mnt/media/library \
  --format '{n} ({y})/{n} ({y})' \
  --action test  # Remove 'test' to execute

# TV
filebot -rename /mnt/media/staging/2-ready/tv \
  --db TheTVDB \
  --output /mnt/media/library \
  --format '{n}/Season {s.pad(2)}/{n} - {s00e00} - {t}' \
  --action test  # Remove 'test' to execute
```

---

## Verification Checklist

- [ ] All files moved to library successfully
- [ ] File names follow proper convention
- [ ] Jellyfin shows new content
- [ ] Sample playback works (test 2-3 files)
- [ ] Metadata looks correct in Jellyfin
- [ ] Staging directory cleaned up

---

## What Remains in Legacy-Media

After migration, these stay for later review:

- **10 "MAYBE" files** (~46.5GB) - acceptable quality but not ideal
- **7 low-quality files** (~17GB) - delete when ready
- **Other collections** - films with scores below 80

---

## Cleanup After Verification

```bash
# Clean staging
rm -rf /mnt/media/staging/2-ready/movies/*
rm -rf /mnt/media/staging/2-ready/tv/*

# Optional: Review then delete legacy-media later
# Keep for now to review other files
```

---

## Documentation

- **Full guide**: `docs/guides/migrate-legacy-top-tier-to-library.md`
- **Quality assessment**: `docs/guides/legacy-library-quality-assessment.md`
- **Cleanup actions**: `docs/guides/legacy-library-cleanup-actions.md`
- **Analysis CSV**: `docs/reference/legacy-media-analysis.csv`
