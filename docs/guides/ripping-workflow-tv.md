# How to Rip a TV Show - Step-by-Step Guide

This guide walks you through the complete workflow for ripping, organizing, and processing TV show discs from disc to Jellyfin library.

## Prerequisites

- TV show disc inserted in optical drive
- SSH access to homelab containers (ripper, analyzer, transcoder)
- Containers running

## Workflow Overview

```
1. Rip (ripper)  →  2. Manual Review  →  3. Remux (analyzer)  →  4. Transcode  →  5. FileBot
   1-ripped/           (organize)           2-remuxed/              3-transcoded/     library/tv/
```

**Important:** TV shows require processing ALL discs of a season before transcoding/FileBot steps.

---

## Step 1: Rip All Discs (ripper)

**For each disc in the season:**

```bash
ssh ripper
cd ~/scripts

# Replace with actual show name, season, and disc number
./run-bg.sh ./rip-disc.sh -t show -n "Show Name" -s 1 -d 1

# Monitor progress
ls ~/active-jobs/                    # See active jobs
tail -f ~/active-jobs/*/rip.log      # Follow live logs
cat ~/active-jobs/*/status           # Check status
```

**Examples:**
```bash
./run-bg.sh ./rip-disc.sh -t show -n "Avatar The Last Airbender" -s 2 -d 1
./run-bg.sh ./rip-disc.sh -t show -n "Avatar The Last Airbender" -s 2 -d 2
./run-bg.sh ./rip-disc.sh -t show -n "Avatar The Last Airbender" -s 2 -d 3
```

**What happens:**
- MakeMKV rips all titles from disc
- Creates organization scaffolding (`_episodes/`, `_extras/`, `_discarded/`)
- Output: `/mnt/media/1-ripped/tv/Show_Name/S02/Disc1/`
- State tracked in `.rip/` directory (status, logs, metadata)
- Time: ~20-60 minutes per disc

**Check rip status:**
```bash
# While running
ls ~/active-jobs/                         # Shows symlinks to active jobs
cat ~/active-jobs/*/status                # "in_progress"

# After completion (symlink removed)
cat /mnt/media/1-ripped/tv/Show_Name/S02/Disc1/.rip/status   # "completed" or "failed"
cat /mnt/media/1-ripped/tv/Show_Name/S02/Disc1/.rip/rip.log  # Full log
```

**Repeat for ALL discs in the season** before proceeding.

---

## Step 2: Manual Review & Organization

**After each disc is ripped, organize the files:**

```bash
# SSH to ripper or any machine with access to staging
cd /mnt/media/1-ripped/tv/Show_Name/S02/Disc1/

# Review the structure
ls -la
# You'll see:
# - ShowName_S02_Disc1_t00.mkv  (raw rips)
# - ShowName_S02_Disc1_t01.mkv
# - ...
# - _episodes/                   (empty, for episodes)
# - _extras/                     (subdirs for each category)
# - _discarded/                  (for duplicates/unwanted)
# - _REVIEW.txt                  (notes template)
# - .rip/                        (state tracking)
```

**Review each file:**
```bash
# Check file info
mediainfo ShowName_S02_Disc1_t00.mkv | head -30

# Or play briefly to identify content
vlc ShowName_S02_Disc1_t00.mkv
```

**Organize episodes:**
```bash
# Rename to episode numbers (based on your research)
mv ShowName_S02_Disc1_t02.mkv 01.mkv    # Episode 1
mv ShowName_S02_Disc1_t03.mkv 02.mkv    # Episode 2
mv ShowName_S02_Disc1_t04.mkv 03.mkv    # Episode 3

# Move to episodes folder
mv 01.mkv 02.mkv 03.mkv _episodes/
```

**Organize extras:**
```bash
# Rename with descriptive names
mv ShowName_S02_Disc1_t05.mkv Making_Of_Season_2.mkv
mv ShowName_S02_Disc1_t06.mkv Cast_Interviews.mkv

# Move to appropriate category
mv Making_Of_Season_2.mkv "_extras/behind the scenes/"
mv Cast_Interviews.mkv "_extras/interviews/"
```

**Discard unwanted:**
```bash
# Duplicates, trailers you don't want, etc.
mv ShowName_S02_Disc1_t00.mkv _discarded/
mv ShowName_S02_Disc1_t01.mkv _discarded/
```

**Update notes:**
```bash
# Edit _REVIEW.txt with your findings
nano _REVIEW.txt
# Add Blu-ray.com URL, episode mapping notes, etc.
```

---

## Step 3: Remux Each Disc (analyzer)

**For each ripped disc:**

```bash
ssh analyzer
cd ~/scripts

# Find ripped folders for your show
ls /mnt/media/1-ripped/tv/Show_Name/S02/

# Run remux script for each disc (processes _episodes/ folder)
./run-bg.sh ./remux.sh -t show -n "Show Name" -s 2 -d 1

# Monitor progress
tail -f ~/logs/remux_*.log
```

**What happens:**
- Remuxes all episodes from `_episodes/` folder
- Preserves manual episode numbering (e.g., `12-13.mkv` → `S02E12-E13.mkv`)
- Removes unwanted streams
- Consolidates all episodes into: `/mnt/media/2-remuxed/tv/Show_Name/Season_02/`
- Copies extras to appropriate subdirectories
- Time: ~5-15 minutes per disc

**Process ALL discs** - they all merge into the same `Season_XX/` folder.

---

## Step 4: Transcode Entire Season (transcoder)

**After ALL discs are remuxed:**

```bash
ssh transcoder
cd ~/scripts

# Transcode the entire season
./run-bg.sh ./transcode.sh -t show -n "Show Name" -s 2

# Monitor progress
tail -f ~/logs/transcode_*.log

# Check job status
cat /mnt/media/2-remuxed/tv/Show_Name/Season_02/.transcode/status
ls /mnt/media/2-remuxed/tv/Show_Name/Season_02/.transcode/queue/
```

**What happens:**
- Transcodes ALL episodes in the season to HEVC (H.265)
- Uses CRF 20 for quality
- Processes episodes sequentially
- State tracked in `.transcode/` directory
- Output: `/mnt/media/3-transcoded/tv/Show_Name/Season_02/`
- Time: ~2-6 hours per episode (can take 12-48 hours for full season)

**This is the longest step.** You can disconnect and check back later.

---

## Step 5: Organize with FileBot (analyzer)

```bash
ssh analyzer
cd ~/scripts

# Preview what FileBot will do (dry-run)
./filebot.sh -t show -n "Show Name" -s 2 --preview

# If preview looks good, run for real
./filebot.sh -t show -n "Show Name" -s 2
```

**What happens:**
- FileBot looks up show in TheTVDB
- Matches episode files to episode metadata
- In preview mode: shows what would be renamed/copied
- In normal mode: copies files (preserves source for safe cleanup)
- Proper naming: `Show Name - S01E01 - Episode Title.mkv`
- Copies to `/mnt/library/tv/Show Name/Season 02/`
- Copies extras to Jellyfin-compatible subdirectories
- State tracked in `.filebot/` directory
- Jellyfin automatically detects new content

**Time:** ~1-2 minutes

---

## Step 6: Verify in Jellyfin

1. Open Jellyfin web UI
2. Navigate to TV Shows library
3. Find your show and season - should have:
   - Proper show name and season
   - All episodes with correct numbers and titles
   - Metadata from TheTVDB
   - Poster and episode thumbnails

---

## Multi-Disc Workflow Example

**Example: Avatar The Last Airbender Season 2 (3 discs)**

### Rip all discs first:
```bash
ssh ripper
cd ~/scripts
./run-bg.sh ./rip-disc.sh -t show -n "Avatar The Last Airbender" -s 2 -d 1
# Wait for completion, swap disc
./run-bg.sh ./rip-disc.sh -t show -n "Avatar The Last Airbender" -s 2 -d 2
# Wait for completion, swap disc
./run-bg.sh ./rip-disc.sh -t show -n "Avatar The Last Airbender" -s 2 -d 3
```

### Manual review each disc:
```bash
# For each disc, identify and organize episodes/extras
cd /mnt/media/1-ripped/tv/Avatar_The_Last_Airbender/S02/Disc1/
# Review files, rename episodes to 01.mkv, 02.mkv, etc.
# Move to _episodes/, organize extras, discard duplicates
```

### Remux all discs:
```bash
ssh analyzer
cd ~/scripts
./run-bg.sh ./remux.sh -t show -n "Avatar The Last Airbender" -s 2 -d 1
./run-bg.sh ./remux.sh -t show -n "Avatar The Last Airbender" -s 2 -d 2
./run-bg.sh ./remux.sh -t show -n "Avatar The Last Airbender" -s 2 -d 3
```

All episodes now in: `/mnt/media/2-remuxed/tv/Avatar_The_Last_Airbender/Season_02/`

### Transcode once for entire season:
```bash
ssh transcoder
cd ~/scripts
./run-bg.sh ./transcode.sh -t show -n "Avatar The Last Airbender" -s 2
```

### FileBot once for entire season:
```bash
ssh analyzer
cd ~/scripts

# Preview first
./filebot.sh -t show -n "Avatar The Last Airbender" -s 2 --preview

# If good, run for real
./filebot.sh -t show -n "Avatar The Last Airbender" -s 2
```

Done! Full season in library.

---

## Quick Reference Commands

### Check active jobs
```bash
ls ~/active-jobs/                    # See all active jobs (symlinks)
cat ~/active-jobs/*/status           # Check status of all jobs
tail -f ~/active-jobs/*/rip.log      # Follow logs of all jobs
```

### Check job state after completion
```bash
# Rip state
cat /path/to/rip/.rip/status         # "completed" or "failed"
cat /path/to/rip/.rip/rip.log        # Full log

# Transcode state
cat /path/to/season/.transcode/status
ls /path/to/season/.transcode/queue/  # Files waiting to be processed

# FileBot state
cat /path/to/season/.filebot/status
cat /path/to/season/.filebot/filebot.log
```

### Check staging directories
```bash
ls /mnt/media/1-ripped/tv/Show_Name/
ls /mnt/media/2-remuxed/tv/Show_Name/
ls /mnt/media/3-transcoded/tv/Show_Name/
ls /mnt/library/tv/
```

---

## Troubleshooting

### Script fails during rip
- Check disc is readable: `makemkvcon info disc:0`
- Try cleaning the disc
- Check drive passthrough: `ls -l /dev/sr0 /dev/sg4`
- Check state: `cat /path/to/rip/.rip/status` → "failed"
- Check error: `cat /path/to/rip/.rip/error`
- Check log: `cat /path/to/rip/.rip/rip.log`

### Can't see active jobs
- Check symlink farm: `ls -la ~/active-jobs/`
- If job crashed, symlink may remain but status is "in_progress" with no PID
- Clean up stale symlinks: `find ~/active-jobs -xtype l -delete`

### FileBot can't match episodes
- Make sure show name is correct (check TheTVDB)
- Use `--id` flag to force specific TVDB ID: `./filebot.sh -t show -n "Name" -s 2 --id 12345`
- Use `--preview` to see what FileBot detects
- Episodes should be in Season_XX folders
- FileBot expects standard naming patterns

### Remux script doesn't find episodes
- Check the `_episodes/` folder has files from manual review step
- Files must be renamed to episode numbers (01.mkv, 02.mkv, etc.)
- For combined episodes, use format like `12-13.mkv`

### Episodes in wrong order
- FileBot uses database episode order
- If disc has episodes out of order, FileBot should correct it
- Verify with TheTVDB episode list

---

## Tips

- **Multi-disc seasons**: Rip all discs first, then batch process the remux steps
- **Background jobs**: Use `run-bg.sh` for all long operations so you can disconnect
- **Episode count**: Note how many episodes are on each disc (usually 3-5)
- **Manual review**: Take time to properly identify episodes and extras - this saves trouble later
- **Extras organization**: Use Jellyfin-compatible folder names (with spaces) in `_extras/`
- **State tracking**: All job state lives in `.rip/`, `.transcode/`, and `.filebot/` directories
- **Safe cleanup**: FileBot uses copy (not move), so source files are preserved until you manually clean up
- **Preview mode**: Use `--preview` flag with filebot.sh to see what will happen before committing
- **Global visibility**: Active jobs symlinked in `~/active-jobs/` for easy monitoring
- **Cleanup**: Scripts preserve source files - clean up staging directories after verification
- **Metadata**: FileBot pulls episode titles, descriptions, and air dates automatically

---

**Last updated:** 2025-11-17
