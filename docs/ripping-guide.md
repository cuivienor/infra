# Media Ripping Guide

End-to-end workflow for ripping movies and TV shows from disc to Jellyfin.

## Workflow Overview

```
1. Rip (ripper)  →  2. Organize (manual)  →  3. Remux (analyzer)  →  4. Transcode (transcoder)  →  5. FileBot (analyzer)
   1-ripped/           _main/, _extras/        2-remuxed/              3-transcoded/                 library/
```

---

## Step 1: Rip the Disc

**SSH to ripper and run:**

```bash
ssh ripper
cd ~/scripts

# Movie
nohup ./rip-disc.sh -t movie -n "Movie Title" &

# TV Show (repeat for each disc)
nohup ./rip-disc.sh -t show -n "Show Name" -s 1 -d 1 &
```

**Monitor:**
```bash
ls ~/active-jobs/                    # List active jobs
tail -f ~/active-jobs/*/rip.log      # Follow logs
cat ~/active-jobs/*/status           # Check status
```

**Output:**
- Movies: `/mnt/media/staging/1-ripped/movies/Movie_Title_YYYY-MM-DD/`
- TV: `/mnt/media/staging/1-ripped/tv/Show_Name/S01/Disc1/`

---

## Step 2: Organize Files (Manual)

After ripping, organize files into the expected structure.

### For Movies

```bash
cd /mnt/media/staging/1-ripped/movies/Movie_Title_YYYY-MM-DD/

# Create organization folders
mkdir -p _main "_extras/behind the scenes" "_extras/deleted scenes" "_extras/featurettes" _discarded

# Identify files (play first few seconds)
mpv --length=30 title_t00.mkv

# Move main feature to _main/
mv title_t00.mkv _main/

# Move extras with descriptive names
mv title_t01.mkv "_extras/behind the scenes/Making Of.mkv"
mv title_t02.mkv "_extras/deleted scenes/Deleted Scenes.mkv"

# Discard duplicates/unwanted
mv title_t03.mkv _discarded/
```

### For TV Shows

```bash
cd /mnt/media/staging/1-ripped/tv/Show_Name/S01/Disc1/

# Create organization folders
mkdir -p _episodes "_extras/behind the scenes" _discarded

# Identify episodes and rename to episode numbers
mv title_t00.mkv _episodes/01.mkv
mv title_t01.mkv _episodes/02.mkv
mv title_t02.mkv _episodes/03.mkv

# For multi-episode files (episodes 12-13 combined)
mv title_t05.mkv _episodes/12-13.mkv

# Move extras with descriptive names
mv title_t03.mkv "_extras/behind the scenes/Making Of Season 1.mkv"

# Discard duplicates/unwanted
mv title_t04.mkv _discarded/
```

**Jellyfin extras folders** (must use spaces): `behind the scenes`, `deleted scenes`, `featurettes`, `interviews`, `shorts`, `trailers`

---

## Step 3: Remux

**SSH to analyzer and run:**

```bash
ssh analyzer
cd ~/scripts

# Movie
nohup ./remux.sh -t movie -n "Movie Title" &

# TV Show (processes all discs for a season)
nohup ./remux.sh -t show -n "Show Name" -s 1 &
```

**Monitor:**
```bash
ls ~/active-jobs/
tail -f ~/active-jobs/*/remux.log
```

**Output:** `/mnt/media/staging/2-remuxed/movies/Movie_Title/` or `.../tv/Show_Name/Season_01/`

---

## Step 4: Transcode

**SSH to transcoder and run:**

```bash
ssh transcoder
cd ~/scripts

# Movie
nohup ./transcode.sh -t movie -n "Movie Title" &

# TV Show
nohup ./transcode.sh -t show -n "Show Name" -s 1 &
```

**Options:**
- `-c <crf>` - Quality (18-28, default 20, lower=better)
- `-m hardware` - Use GPU encoding (faster, larger files)

**Monitor:**
```bash
ls ~/active-jobs/
tail -f ~/active-jobs/*/transcode.log
```

**Note:** This is the longest step (2-6 hours per movie, longer for TV seasons). Safe to disconnect.

**Output:** `/mnt/media/staging/3-transcoded/movies/Movie_Title/` or `.../tv/Show_Name/Season_01/`

---

## Step 5: FileBot

**SSH to analyzer and run:**

```bash
ssh analyzer
cd ~/scripts

# Preview first (dry-run)
./filebot.sh -t movie -n "Movie Title" --preview
./filebot.sh -t show -n "Show Name" -s 1 --preview

# If preview looks good, run for real
./filebot.sh -t movie -n "Movie Title"
./filebot.sh -t show -n "Show Name" -s 1
```

**If wrong match:** Use `--id` to force specific database ID:
```bash
./filebot.sh -t show -n "Show Name" -s 1 --id 12345
```

**Output:** `/mnt/media/library/movies/Movie Name (Year)/` or `.../tv/Show Name/Season 01/`

---

## Step 6: Verify & Cleanup

1. Check Jellyfin - movie/show should appear with metadata and artwork
2. Clean up staging (after verification):
   ```bash
   rm -rf /mnt/media/staging/1-ripped/movies/Movie_Title_*/
   rm -rf /mnt/media/staging/2-remuxed/movies/Movie_Title/
   rm -rf /mnt/media/staging/3-transcoded/movies/Movie_Title/
   ```

---

## Multi-Disc Movies

For movies spanning multiple discs:

1. Rip each disc separately
2. Merge all files into one folder before organizing:
   ```bash
   mkdir /mnt/media/staging/1-ripped/movies/Movie_Title_merged/
   mv /mnt/media/staging/1-ripped/movies/Movie_Title_Disc1_*/*.mkv /mnt/media/staging/1-ripped/movies/Movie_Title_merged/
   mv /mnt/media/staging/1-ripped/movies/Movie_Title_Disc2_*/*.mkv /mnt/media/staging/1-ripped/movies/Movie_Title_merged/
   ```
3. Continue with organize → remux → transcode → filebot

---

## Quick Reference

| Step | Container | Command |
|------|-----------|---------|
| Rip | ripper | `nohup ./rip-disc.sh -t movie -n "Name" &` |
| Remux | analyzer | `nohup ./remux.sh -t movie -n "Name" &` |
| Transcode | transcoder | `nohup ./transcode.sh -t movie -n "Name" &` |
| FileBot | analyzer | `./filebot.sh -t movie -n "Name" --preview` |

**Monitoring:** `ls ~/active-jobs/` then `tail -f ~/active-jobs/*/[script].log`

**Staging paths:**
- `1-ripped` → `2-remuxed` → `3-transcoded` → `library`
