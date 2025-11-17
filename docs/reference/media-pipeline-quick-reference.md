# Media Pipeline Quick Reference

## Pipeline Overview

```
1-ripped/ → 2-remuxed/ → 3-transcoded/ → library/
   ↓            ↓             ↓              ↓
 rip-disc    remux.sh    transcode.sh    filebot.sh
```

All scripts use consistent CLI: `-t <type> -n <name> [-s <season>]`

---

## Scripts

### 1. Rip Disc (ripper container)
```bash
# TV show disc
./rip-disc.sh -t show -n "Avatar The Last Airbender" -s 2 -d 1

# Movie
./rip-disc.sh -t movie -n "The Lion King"
```
**Output**: `1-ripped/tv/Avatar_The_Last_Airbender/S02/Disc1/`

**Manual Step**: Organize raw files into:
- `_episodes/` - numbered as `01.mkv`, `02.mkv`, or `12-13.mkv` for multi-episode
- `_extras/{category}/` - featurettes, shorts, interviews, etc.
- `_discarded/` - duplicates and unwanted tracks

### 2. Remux (analyzer container)
```bash
# TV season (processes all discs)
./remux.sh -t show -n "Avatar The Last Airbender" -s 2

# Movie
./remux.sh -t movie -n "The Lion King"
```
**Output**: `2-remuxed/tv/Avatar_The_Last_Airbender/Season_02/S02E01.mkv`

Filters to English/Bulgarian audio and subtitles only.

### 3. Transcode (transcoder container)
```bash
# TV season
nohup ./transcode.sh -t show -n "Avatar The Last Airbender" -s 2 &

# Movie with custom quality
nohup ./transcode.sh -t movie -n "The Lion King" -c 18 -m hardware &
```
**Options**: `-c` CRF (18-28, default 20), `-m` mode (software/hardware)

**Output**: `3-transcoded/tv/Avatar_The_Last_Airbender/Season_02/`

### 4. Library Organization (analyzer container)
```bash
# Preview first
./filebot.sh -t show -n "Avatar The Last Airbender" -s 2 --preview

# Execute (interactive - will prompt for confirmation)
./filebot.sh -t show -n "Avatar The Last Airbender" -s 2
```
**Output**: `library/tv/Avatar The Last Airbender/Season 02/`

---

## Monitoring Jobs

### Active Jobs
```bash
ls ~/active-jobs/                           # List all active jobs
cat ~/active-jobs/*/status                  # Check status
tail -f ~/active-jobs/*/transcode.log       # Follow logs
```

### Job State Directories
Each stage creates a hidden state directory (`.rip/`, `.remux/`, `.transcode/`, `.filebot/`):
```bash
# Check transcode status
cat /mnt/media/staging/3-transcoded/tv/Show/Season_01/.transcode/status

# View metadata
cat /mnt/media/staging/3-transcoded/tv/Show/Season_01/.transcode/metadata.json

# Check what's completed
cat /mnt/media/staging/3-transcoded/tv/Show/Season_01/.transcode/completed.txt
```

### Resume After Failure
```bash
# Just re-run the same command - skips completed files
nohup ./transcode.sh -t show -n "Show Name" -s 1 &
```

---

## Debugging

### FileBot Wrong Match
```bash
# Preview shows wrong series
./filebot.sh -t show -n "Cosmos" -s 1 --preview
# Output shows: Cosmos (2014) [260586]

# Use --id to force specific database ID
./filebot.sh -t show -n "Cosmos" -s 1 --id 260586
```

### Check File Details
```bash
mediainfo file.mkv                    # Audio/video tracks
mkvmerge -i file.mkv                  # Track listing
```

### Check Disk Space
```bash
df -h /mnt/media
du -sh /mnt/media/staging/*
```

---

## Container Access

| Container   | CTID | SSH Access                      | Scripts Location |
|------------|------|----------------------------------|-----------------|
| Ripper     | 302  | `ssh media@ripper.home.arpa`    | `~/scripts/`    |
| Analyzer   | 303  | `ssh media@analyzer.home.arpa`  | `~/scripts/`    |
| Transcoder | 304  | `ssh media@transcoder.home.arpa`| `~/scripts/`    |

All containers mount `/mnt/storage/media` → `/mnt/media`

---

## Jellyfin-Compatible Extras

Organize extras in these directories (preserved through entire pipeline):
- `behind the scenes/`
- `deleted scenes/`
- `featurettes/`
- `interviews/`
- `scenes/`
- `shorts/`
- `trailers/`
- `other/`

---

## Cleanup (Manual)

After verifying files in Jellyfin:
```bash
# Remove transcoded source (library copy is safe)
rm -rf /mnt/media/staging/3-transcoded/tv/Show_Name/Season_01/

# Remove remuxed source
rm -rf /mnt/media/staging/2-remuxed/tv/Show_Name/Season_02/

# Remove ripped source (only after everything verified)
rm -rf /mnt/media/staging/1-ripped/tv/Show_Name/
```
