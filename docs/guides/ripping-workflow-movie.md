# How to Rip a Movie - Step-by-Step Guide

This guide walks you through the complete workflow for ripping, transcoding, and organizing a movie from disc to Jellyfin library.

## Prerequisites

- Movie disc inserted in optical drive
- SSH access to homelab containers (ct302, ct303, ct304)
- Containers running (ripper, analyzer, transcoder)

## Workflow Overview

```
1. Rip (CT302)  →  2. Remux (CT303)  →  3. Transcode (CT304)  →  4. FileBot (CT303)
   1-ripped/           2-remuxed/           3-transcoded/           library/movies/
```

**For multi-disc movies**: Rip all discs first → Merge into single folder → Continue workflow

See [Multi-Disc Movies](#multi-disc-movies) section below for detailed instructions.

---

## Step 1: Rip the Disc (CT302 - ripper)

**Insert the Blu-ray/DVD disc**, then:

```bash
ssh ct302
cd ~/scripts

./run-bg.sh ./rip-disc.sh movie "Movie Title Here"

# Monitor progress
tail -f ~/logs/rip-disc_*.log
```

**What happens:**
- MakeMKV rips all titles from disc
- Output: `/mnt/staging/1-ripped/movies/Movie_Title_Here_YYYY-MM-DD/`
- Time: ~20-60 minutes depending on disc size

**Wait for completion** before proceeding.

> **📀 Multi-Disc Movie?** If your movie spans multiple discs (like "How to Train Your Dragon: The Hidden World"), see the [Multi-Disc Movies](#multi-disc-movies) section below for special instructions. You'll need to rip all discs first, then merge them into one folder before Step 2.

---

## Step 2: Analyze & Remux (CT303 - analyzer)

> **💡 Tip**: Your extras will have generic names (`title_t01.mkv`) for now. This is fine! You can organize and rename them properly in Jellyfin after FileBot completes. See [Extras Labeling Workflow](extras-labeling-workflow.md) for details.

```bash
ssh ct303
cd ~/scripts

# Find the exact folder name (with date stamp)
ls /mnt/staging/1-ripped/movies/ | grep -i "movie title"

# Run organize script (replace YYYY-MM-DD with actual date)
./run-bg.sh ./organize-and-remux-movie.sh /mnt/staging/1-ripped/movies/Movie_Title_Here_YYYY-MM-DD/

# Monitor progress
tail -f ~/logs/organize-and-remux-movie_*.log
```

**What happens:**
- Analyzes all MKV files
- Identifies main movie and extras (by duration >30min and size >5GB)
- Remuxes to remove unwanted streams
- Output: `/mnt/staging/2-remuxed/movies/Movie_Title_Here/` (date stamp removed)
- Time: ~5-15 minutes

**Wait for completion** before proceeding.

---

## Step 3: Transcode (CT304 - transcoder)

```bash
ssh ct304
cd ~/scripts

# Note: folder name has NO date stamp now
./run-bg.sh ./transcode-queue.sh /mnt/staging/2-remuxed/movies/Movie_Title_Here/ 20 software --auto

# Monitor progress
tail -f ~/logs/transcode-queue_*.log
```

**What happens:**
- Transcodes video to HEVC (H.265) using CRF 20
- Copies audio and subtitle streams as-is
- Preserves extras in subdirectories
- Output: `/mnt/staging/3-transcoded/movies/Movie_Title_Here/`
- Time: ~2-6 hours depending on length and quality

**This is the longest step.** You can disconnect and check back later.

---

## Step 4: Organize with FileBot (CT303 - analyzer)

```bash
ssh ct303
cd ~/scripts

./filebot-process.sh /mnt/staging/3-transcoded/movies/Movie_Title_Here/
```

**What happens:**
- FileBot looks up movie in TheMovieDB
- Shows preview of rename/move operation
- **Prompts for confirmation** - review carefully!
- Type `y` to confirm
- Moves main movie to `/mnt/library/movies/Movie Name (Year)/`
- Copies extras to `extras/` subdirectory
- Jellyfin automatically detects new content

**Time:** ~1-2 minutes

---

## Step 5: Verify in Jellyfin

1. Open Jellyfin web UI
2. Navigate to Movies library
3. Find your movie - should have:
   - Proper title and year
   - Metadata from TheMovieDB
   - Poster art
   - Extras in "Special Features" section

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
ls /mnt/staging/1-ripped/movies/
ls /mnt/staging/2-remuxed/movies/
ls /mnt/staging/3-transcoded/movies/
ls /mnt/library/movies/
```

---

## Multi-Disc Movies

Some movies span **multiple discs** (e.g., extended editions, director's cuts with bonus disc). The workflow differs slightly from single-disc movies.

### Strategy: Merge Before Processing

**Best Practice**: Rip all discs first, then **manually merge** into one folder before running organize/remux.

#### Step-by-Step for Multi-Disc Movies

1. **Rip Disc 1** with a descriptive name:
   ```bash
   ssh ct302
   cd ~/scripts
   ./run-bg.sh ./rip-disc.sh movie "How to Train Your Dragon 3 Disc 1"
   ```

2. **Rip Disc 2** with matching name:
   ```bash
   # Wait for Disc 1 to finish, then swap discs
   ./run-bg.sh ./rip-disc.sh movie "How to Train Your Dragon 3 Disc 2"
   ```

3. **Merge the ripped files** into a single directory:
   ```bash
   ssh ct303  # Switch to analyzer container

   # List the ripped directories
   ls /mnt/staging/1-ripped/movies/ | grep -i "dragon"

   # Create a merged directory
   mkdir -p /mnt/staging/1-ripped/movies/How_to_Train_Your_Dragon_3_merged

   # Move all MKV files from both discs into merged folder
   mv /mnt/staging/1-ripped/movies/How_to_Train_Your_Dragon_3_Disc_1_2024-11-13/*.mkv \
      /mnt/staging/1-ripped/movies/How_to_Train_Your_Dragon_3_merged/

   mv /mnt/staging/1-ripped/movies/How_to_Train_Your_Dragon_3_Disc_2_2024-11-13/*.mkv \
      /mnt/staging/1-ripped/movies/How_to_Train_Your_Dragon_3_merged/
   ```

4. **Continue normal workflow** using the merged folder:
   ```bash
   # Now proceed with organize-and-remux
   ./run-bg.sh ./organize-and-remux-movie.sh \
     /mnt/staging/1-ripped/movies/How_to_Train_Your_Dragon_3_merged/
   ```

5. **Cleanup** the original disc folders after verification:
   ```bash
   # After confirming merged folder looks good
   rm -rf /mnt/staging/1-ripped/movies/How_to_Train_Your_Dragon_3_Disc_*
   ```

### Why Merge First?

- **organize-and-remux-movie.sh** analyzes all MKV files in a folder together
- It auto-detects main features vs extras by duration/size
- Multi-disc movies often have:
  - **Disc 1**: Main movie
  - **Disc 2**: Extras (behind the scenes, deleted scenes, etc.)
- By merging first, the script correctly categorizes everything in one pass

### Alternative: Manual Processing

If you prefer manual control:

1. Process each disc separately through organize/remux/transcode
2. After FileBot, manually move extras from Disc 2 to the Disc 1 movie folder:
   ```bash
   # Example: Move Disc 2 extras to main movie folder
   mv /mnt/library/movies/Movie\ Name\ \(Year\)\ Disc\ 2/* \
      /mnt/library/movies/Movie\ Name\ \(Year\)/extras/

   # Delete the Disc 2 movie entry
   rm -rf /mnt/library/movies/Movie\ Name\ \(Year\)\ Disc\ 2
   ```

---

## Troubleshooting

### Script fails during rip
- Check disc is readable: `makemkvcon info disc:0`
- Try cleaning the disc
- Check drive passthrough: `ls -l /dev/sr0 /dev/sg4`

### FileBot can't find movie
- Make sure movie title is clear and unambiguous
- Add year to folder name if multiple versions exist
- Check TheMovieDB to verify movie exists

### Transcode is slow
- This is normal for software encoding
- Hardware encoding can be faster but larger files
- Consider letting it run overnight

### Files in wrong location
- Each step outputs to a specific staging directory
- Use the exact paths shown in this guide
- The scripts auto-detect mount points now

### Multi-disc: Wrong files categorized as main feature
- The script uses >30min AND >5GB as criteria for main features
- If extras are large/long, they may be miscategorized
- Review the categorization when organize-and-remux prompts for confirmation
- You can manually move files between main folder and extras/ afterward

---

## Tips

- **Background jobs**: All long-running scripts use `run-bg.sh` so you can disconnect
- **Monitor remotely**: SSH back in anytime to check `tail -f ~/logs/`
- **Multiple discs**: Rip all discs first, then merge into one folder before processing
- **Cleanup**: Scripts automatically clean up staging directories after FileBot completes
- **Verify before transcoding**: Always check organize-and-remux output before starting the long transcode step
- **Organize extras in Jellyfin**: Use Jellyfin category folders for clean presentation - see [Extras Labeling Workflow](extras-labeling-workflow.md)

---

**Last updated:** 2025-11-13
