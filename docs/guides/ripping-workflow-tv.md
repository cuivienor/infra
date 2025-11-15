# How to Rip a TV Show - Step-by-Step Guide

This guide walks you through the complete workflow for ripping, transcoding, and organizing TV show discs from disc to Jellyfin library.

## Prerequisites

- TV show disc inserted in optical drive
- SSH access to homelab containers (ripper, analyzer, transcoder)
- Containers running

## Workflow Overview

```
1. Rip (ripper)  →  2. Remux (analyzer)  →  3. Transcode (transcoder)  →  4. FileBot (analyzer)
   1-ripped/           2-remuxed/              3-transcoded/                 library/tv/
```

**Important:** TV shows require processing ALL discs of a season before transcoding/FileBot steps.

---

## Step 1: Rip All Discs (ripper)

**For each disc in the season:**

```bash
ssh ripper
cd ~/scripts

# Replace with actual show name and disc info
./run-bg.sh ./rip-disc.sh show "Show Name" "S01 Disc1"

# Monitor progress
tail -f ~/logs/rip-disc_*.log
```

**Examples:**
```bash
./run-bg.sh ./rip-disc.sh show "Avatar The Last Airbender" "S02 Disc1"
./run-bg.sh ./rip-disc.sh show "Avatar The Last Airbender" "S02 Disc2"
./run-bg.sh ./rip-disc.sh show "Avatar The Last Airbender" "S02 Disc3"
```

**What happens:**
- MakeMKV rips all titles from disc
- Output: `/mnt/staging/1-ripped/tv/Show_Name/S01_Disc1_YYYY-MM-DD/`
- Time: ~20-60 minutes per disc

**Repeat for ALL discs in the season** before proceeding.

---

## Step 2: Organize & Remux Each Disc (analyzer)

**For each ripped disc:**

```bash
ssh analyzer
cd ~/scripts

# Find ripped folders for your show
ls /mnt/staging/1-ripped/tv/Show_Name/

# Run organize script for each disc (replace dates with actual)
./run-bg.sh ./organize-and-remux-tv.sh /mnt/staging/1-ripped/tv/Show_Name/S01_Disc1_YYYY-MM-DD/

# Monitor progress
tail -f ~/logs/organize-and-remux-tv_*.log
```

**What happens:**
- Analyzes all episodes on the disc
- Identifies episode files (usually largest titles)
- Remuxes to remove unwanted streams
- Consolidates all episodes into: `/mnt/staging/2-remuxed/tv/Show_Name/Season_01/`
- Time: ~5-15 minutes per disc

**Process ALL discs** - they all merge into the same `Season_XX/` folder.

---

## Step 3: Transcode Entire Season (transcoder)

**After ALL discs are remuxed:**

```bash
ssh transcoder
cd ~/scripts

# Transcode the entire season folder
./run-bg.sh ./transcode-queue.sh /mnt/staging/2-remuxed/tv/Show_Name/Season_01/ 20 software --auto

# Monitor progress
tail -f ~/logs/transcode-queue_*.log
```

**What happens:**
- Transcodes ALL episodes in the season to HEVC (H.265)
- Uses CRF 20 for quality
- Processes episodes sequentially
- Output: `/mnt/staging/3-transcoded/tv/Show_Name/Season_01/`
- Time: ~2-6 hours per episode (can take 12-48 hours for full season)

**This is the longest step.** You can disconnect and check back later.

---

## Step 4: Organize with FileBot (analyzer)

```bash
ssh analyzer
cd ~/scripts

./filebot-process.sh /mnt/staging/3-transcoded/tv/Show_Name/Season_01/
```

**What happens:**
- FileBot looks up show in TheTVDB
- Matches episode files to episode metadata
- Shows preview with proper naming: `Show Name - S01E01 - Episode Title.mkv`
- **Prompts for confirmation** - review carefully!
- Type `y` to confirm
- Moves to `/mnt/library/tv/Show Name/Season 01/`
- Jellyfin automatically detects new content

**Time:** ~1-2 minutes

---

## Step 5: Verify in Jellyfin

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
./run-bg.sh ./rip-disc.sh show "Avatar The Last Airbender" "S02 Disc1"
# Wait for completion, swap disc
./run-bg.sh ./rip-disc.sh show "Avatar The Last Airbender" "S02 Disc2"
# Wait for completion, swap disc
./run-bg.sh ./rip-disc.sh show "Avatar The Last Airbender" "S02 Disc3"
```

### Remux all discs:
```bash
ssh analyzer
cd ~/scripts
./run-bg.sh ./organize-and-remux-tv.sh /mnt/staging/1-ripped/tv/Avatar_The_Last_Airbender/S02_Disc1_2025-11-13/
./run-bg.sh ./organize-and-remux-tv.sh /mnt/staging/1-ripped/tv/Avatar_The_Last_Airbender/S02_Disc2_2025-11-13/
./run-bg.sh ./organize-and-remux-tv.sh /mnt/staging/1-ripped/tv/Avatar_The_Last_Airbender/S02_Disc3_2025-11-13/
```

All episodes now in: `/mnt/staging/2-remuxed/tv/Avatar_The_Last_Airbender/Season_02/`

### Transcode once for entire season:
```bash
ssh transcoder
cd ~/scripts
./run-bg.sh ./transcode-queue.sh /mnt/staging/2-remuxed/tv/Avatar_The_Last_Airbender/Season_02/ 20 software --auto
```

### FileBot once for entire season:
```bash
ssh analyzer
cd ~/scripts
./filebot-process.sh /mnt/staging/3-transcoded/tv/Avatar_The_Last_Airbender/Season_02/
```

Done! Full season in library.

---

## Quick Reference Commands

### Check what's running
```bash
# On any container
ps aux | grep media
```

### Check latest log
```bash
ls -lt ~/logs/ | head -5
tail -f ~/logs/script-name_*.log
```

### Check staging directories
```bash
ls /mnt/staging/1-ripped/tv/Show_Name/
ls /mnt/staging/2-remuxed/tv/Show_Name/
ls /mnt/staging/3-transcoded/tv/Show_Name/
ls /mnt/library/tv/
```

---

## Troubleshooting

### Script fails during rip
- Check disc is readable: `makemkvcon info disc:0`
- Try cleaning the disc
- Check drive passthrough: `ls -l /dev/sr0 /dev/sg4`

### FileBot can't match episodes
- Make sure show name is correct (check TheTVDB)
- Episodes should be in Season_XX folders
- FileBot expects standard naming patterns

### Remux script doesn't find episodes
- Check the MKV files were actually created in 1-ripped
- Episodes are usually the largest titles (>100MB typically)
- Review organize script output for clues

### Episodes in wrong order
- FileBot uses database episode order
- If disc has episodes out of order, FileBot should correct it
- Verify with TheTVDB episode list

---

## Tips

- **Multi-disc seasons**: Rip all discs first, then batch process the remux steps
- **Background jobs**: Use `run-bg.sh` for all long operations so you can disconnect
- **Episode count**: Note how many episodes are on each disc (usually 3-5)
- **Cleanup**: Scripts clean up staging directories after FileBot completes
- **Metadata**: FileBot pulls episode titles, descriptions, and air dates automatically

---

**Last updated:** 2025-11-13
