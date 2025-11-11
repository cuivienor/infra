# Media Pipeline - Quick Reference Guide

**Last Updated**: 2025-11-10

## Directory Structure

```
/mnt/storage/media/
├── staging/
│   ├── 1-ripped/      # Fresh from disc → analyze here
│   ├── 2-remuxed/     # Track filtered → transcode here
│   ├── 3-transcoded/  # Quality check → promote here
│   └── 4-ready/       # Ready for FileBot → library
└── library/
    ├── movies/        # Final movie library (Jellyfin)
    └── tv/            # Final TV library (Jellyfin)
```

---

## Complete Workflows

### Movie Workflow

```bash
# 1. RIP (CT 200 - ripper)
./rip-disc.sh movie "Movie Name"
# → /staging/1-ripped/movies/Movie_Name_2024-11-10/

# 2. ANALYZE
./analyze-media.sh /staging/1-ripped/movies/Movie_Name_2024-11-10/
# Review in Jellyfin "Staging - Ripped", delete unwanted files

# 3. ORGANIZE & REMUX (CT 201 - transcoder)
./organize-and-remux-movie.sh /staging/1-ripped/movies/Movie_Name_2024-11-10/
# → /staging/2-remuxed/movies/Movie_Name_2024-11-10/
# (auto-separates extras into extras/ subfolder)

# 4. TRANSCODE
./transcode-queue.sh /staging/2-remuxed/movies/Movie_Name_2024-11-10/ 20 software --auto
# → /staging/3-transcoded/movies/Movie_Name_2024-11-10/

# 5. PROMOTE (after quality check in Jellyfin)
./promote-to-ready.sh /staging/3-transcoded/movies/Movie_Name_2024-11-10/
# → /staging/4-ready/movies/Movie_Name/

# 6. FILEBOT
./filebot-process.sh /staging/4-ready/movies/Movie_Name/
# → /library/movies/Movie Name (Year)/
```

### TV Show Workflow

```bash
# 1. RIP ALL DISCS for a season (CT 200 - ripper)
./rip-disc.sh show "Show Name" "S01 Disc1"
./rip-disc.sh show "Show Name" "S01 Disc2"
# → /staging/1-ripped/tv/Show_Name/S01_Disc*_2024-11-10/

# 2. ANALYZE each disc
./analyze-media.sh /staging/1-ripped/tv/Show_Name/S01_Disc1_2024-11-10/
./analyze-media.sh /staging/1-ripped/tv/Show_Name/S01_Disc2_2024-11-10/
# Review in Jellyfin, delete unwanted files

# 3. ORGANIZE & REMUX entire season (CT 201 - transcoder)
./organize-and-remux-tv.sh "Show Name" 01
# Interactive: mark extras, confirm episode numbering
# → /staging/2-remuxed/tv/Show_Name/Season_01/

# 4. TRANSCODE
./transcode-queue.sh /staging/2-remuxed/tv/Show_Name/Season_01/ 20 software --auto
# → /staging/3-transcoded/tv/Show_Name/Season_01/

# 5. PROMOTE
./promote-to-ready.sh /staging/3-transcoded/tv/Show_Name/Season_01/
# → /staging/4-ready/tv/Show_Name/Season_01/

# 6. FILEBOT
./filebot-process.sh /staging/4-ready/tv/Show_Name/Season_01/
# → /library/tv/Show Name/Season 01/
```

---

## Script Reference

### rip-disc.sh (CT 200)

```bash
# Movies
./rip-disc.sh movie "The Matrix"

# TV Shows (specify season and disc)
./rip-disc.sh show "Breaking Bad" "S01 Disc1"
```

**Output**: `/staging/1-ripped/[type]/[Name]_YYYY-MM-DD/`  
**Files**: `[Name]_t##.mkv` (MakeMKV default naming)

---

### analyze-media.sh (CT 201)

```bash
./analyze-media.sh /staging/1-ripped/movies/Movie_2024-11-10/
```

**Shows**:
- File list with duration, size, resolution, track counts
- Duplicate detection (same duration ±5 min)
- Categorization (main features, extras, clips)

**Saves**: `.analysis.txt` in same directory

---

### organize-and-remux-movie.sh (CT 201)

```bash
./organize-and-remux-movie.sh /staging/1-ripped/movies/Movie_2024-11-10/
```

**Does**:
- Categorizes: main features (>30min, >5GB) vs extras
- Remuxes to remove non-English/Bulgarian tracks
- Creates `extras/` subfolder automatically

**Output**: `/staging/2-remuxed/movies/Movie_2024-11-10/`

---

### organize-and-remux-tv.sh (CT 201)

```bash
./organize-and-remux-tv.sh "Show Name" 01
```

**Does**:
- Finds all `S01_Disc*` folders
- Lists all files in disc/track order
- Interactive: mark extras, name them
- Auto-numbers remaining files as episodes
- Remuxes with track filtering

**Output**: `/staging/2-remuxed/tv/Show_Name/Season_01/`

---

### transcode-queue.sh (CT 201)

```bash
# Interactive
./transcode-queue.sh /staging/2-remuxed/movies/Movie_2024-11-10/ 20 software

# Background (nohup)
nohup ./transcode-queue.sh /staging/2-remuxed/movies/Movie/ 20 software --auto > ~/transcode.log 2>&1 &

# Hardware encoding (faster)
./transcode-queue.sh /staging/2-remuxed/movies/Movie/ 22 hardware --auto
```

**Options**:
- CRF: 18-22 (18=highest quality, 22=smaller files)
- Mode: `software` (libx265, best quality) or `hardware` (hevc_qsv, faster)
- `--auto`: Skip confirmation (for nohup)

**Output**: `/staging/3-transcoded/[type]/[folder]/` (mirrors input structure)

---

### promote-to-ready.sh (CT 201)

```bash
./promote-to-ready.sh /staging/3-transcoded/movies/Movie_2024-11-10/
```

**Does**:
- Removes date stamp from folder name
- Copies files to `/staging/4-ready/`
- Optionally deletes source after verification

**Output**: `/staging/4-ready/movies/Movie_Name/`

---

### filebot-process.sh (CT 201)

```bash
./filebot-process.sh /staging/4-ready/movies/Movie_Name/
```

**Does**:
- Dry-run preview (shows what will change)
- Prompts for confirmation
- Moves files to library with proper naming
- Fetches metadata from TheMovieDB/TheTVDB

**Output**: `/library/movies/Movie Name (Year)/` or `/library/tv/Show Name/Season ##/`

---

## Monitoring & Logs

### Check transcode progress

```bash
# View live progress
tail -f ~/transcode.log

# Check queue status
ls -lh /staging/2-remuxed/movies/Movie/.transcode_queue/
cat /staging/2-remuxed/movies/Movie/.transcode_queue/completed.txt
```

### Check disk space

```bash
df -h /mnt/storage
du -sh /mnt/storage/media/staging/*
```

### View file details

```bash
# Quick info
mediainfo file.mkv

# JSON output
mkvmerge -J file.mkv | jq
```

---

## Jellyfin Libraries

| Library | Path | Type | Metadata |
|---------|------|------|----------|
| Staging - Ripped | `/staging/1-ripped` | Folders | Disabled |
| Staging - Remuxed | `/staging/2-remuxed` | Folders | Disabled |
| Staging - Transcoded | `/staging/3-transcoded` | Folders | Disabled |
| Staging - Ready | `/staging/4-ready` | Folders | Disabled |
| Movies | `/library/movies` | Movies | Enabled |
| TV Shows | `/library/tv` | TV Shows | Enabled |

---

## Common Tasks

### Resume interrupted transcode

```bash
# Just run the same command again - it auto-resumes
./transcode-queue.sh /staging/2-remuxed/movies/Movie/ 20 software --auto
```

### Re-analyze after deleting files

```bash
./analyze-media.sh /staging/1-ripped/movies/Movie_2024-11-10/
# Check new .analysis.txt
```

### Manually delete extras

```bash
# After analysis shows extras you don't want
cd /staging/1-ripped/movies/Movie_2024-11-10/
rm -f Movie_Name_t02.mkv Movie_Name_t03.mkv
```

### Check what's in each stage

```bash
find /mnt/storage/media/staging/1-ripped -name "*.mkv" | wc -l
find /mnt/storage/media/staging/2-remuxed -name "*.mkv" | wc -l
find /mnt/storage/media/staging/3-transcoded -name "*.mkv" | wc -l
find /mnt/storage/media/staging/4-ready -name "*.mkv" | wc -l
```

---

## Troubleshooting

### "No discs found for Season ##"

**Issue**: organize-and-remux-tv.sh can't find disc folders  
**Fix**: Check folder naming matches pattern `S##_Disc*`

```bash
# List what exists
ls -la /staging/1-ripped/tv/Show_Name/

# Rename if needed
mv "S1_Disc1_2024-11-10" "S01_Disc1_2024-11-10"
```

### "FileBot not installed"

**Issue**: filebot-process.sh can't run  
**Fix**: Install FileBot (requires license for advanced features)

```bash
# Debian/Ubuntu
wget https://get.filebot.net/filebot/...
dpkg -i filebot_*.deb
```

### Transcode failed with segfault

**Issue**: System overload, ran out of memory  
**Fix**: Already mitigated with CPU units (512 for transcoder)

Check logs: `cat /staging/2-remuxed/Movie/.transcode_queue/logs/*.log`

### Files in wrong category (main vs extras)

**Issue**: organize-and-remux-movie.sh categorized incorrectly  
**Fix**: Manually move files before transcoding

```bash
cd /staging/2-remuxed/movies/Movie_2024-11-10/
mv extras/Some_File.mkv ./
# or
mv Some_File.mkv extras/
```

---

## Performance Tips

### Batch processing

```bash
# Rip multiple discs first, then process all at once
./rip-disc.sh show "Show" "S01 Disc1"
./rip-disc.sh show "Show" "S01 Disc2"
./rip-disc.sh show "Show" "S01 Disc3"

# Then organize entire season
./organize-and-remux-tv.sh "Show" 01
```

### Parallel transcoding

- Don't run multiple transcodes simultaneously (CPU overload)
- Queue handles one at a time
- Can rip on CT 200 while transcoding on CT 201

### Hardware vs Software encoding

| Mode | Speed | Quality | Use For |
|------|-------|---------|---------|
| Software | Slow (10-25h/movie) | Best | Archival, permanent copies |
| Hardware | Fast (2-3h/movie) | Good | Large batches, temporary viewing |

---

## File Naming Patterns

### Stage 1 - Ripped
- Movies: `Movie_Name_t##.mkv`
- TV: `Show_Name_t##.mkv`

### Stage 2 - Remuxed
- Movies: `Movie_Name_t##.mkv` (same name, filtered tracks)
- TV: `S##E##.mkv`
- Extras: in `extras/` subfolder

### Stage 3 - Transcoded
- Same as Stage 2 (mirrors structure)

### Stage 4 - Ready
- Same as Stage 2-3 (date stamp removed from folder)

### Stage 5 - Library (FileBot output)
- Movies: `Movie Name (Year).mkv`
- TV: `Show Name - S##E## - Episode Title.mkv`

---

**For detailed documentation, see**:
- `directory-migration-plan.md` - Setup new structure
- `jellyfin-setup-guide.md` - Configure Jellyfin
- `homelab-media-pipeline-implementation.md` - Original implementation notes
