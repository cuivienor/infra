# Testing Updated organize-and-remux-tv.sh on CT303 Analyzer

## Container Info
- **Container**: CT303 (analyzer)
- **IP**: 192.168.1.73
- **Script Location**: `/home/media/scripts/organize-and-remux-tv.sh`
- **User**: media (UID 1000)

---

## Quick Test with Avatar Season 1

### 1. SSH to the Container
```bash
# From your workstation (SSH config already set up)
ssh ct303

# Or use full address
ssh media@192.168.1.73
```

### 2. Verify Script is Deployed
```bash
ls -lh ~/scripts/organize-and-remux-tv.sh
```

You should see:
```
-rwxr-xr-x 1 media media 10K Nov 11 16:07 /home/media/scripts/organize-and-remux-tv.sh
```

### 3. Check Input Directory Structure
```bash
# View the Avatar directory structure
tree -L 3 /mnt/storage/media/staging/1-ripped/tv/Avatar_The_Last_Airbender/
```

Expected structure:
```
Avatar_The_Last_Airbender/
├── S01_Disc1_2025-11-10/
│   ├── Avatar_The_Last_Airbender_Disc1_t00.mkv   (episode)
│   ├── Avatar_The_Last_Airbender_Disc1_t10.mkv   (episode)
│   ├── ...
│   └── discarded/                                 (will be ignored)
├── S01_Disc2_2025-11-10/
│   ├── Avatar_The_Last_Airbender_Disc2_t08.mkv   (episode)
│   ├── ...
│   ├── discarded/                                 (will be ignored)
│   └── extras/
│       ├── Avatar_The_Last_Airbender_Disc2_t17.mkv
│       └── Avatar_The_Last_Airbender_Disc2_t19.mkv
└── S01_Disc3_2025-11-10/
    ├── Avatar_The_Last_Airbender_S01_Disc3_t00.mkv (episode)
    ├── ...
    ├── discarded/                                   (will be ignored)
    └── extras/
        ├── Avatar_The_Last_Airbender_S01_Disc3_t09.mkv
        └── ...
```

### 4. Run the Script (DRY RUN - Review Only)
```bash
~/scripts/organize-and-remux-tv.sh "Avatar The Last Airbender" 01
```

**What to Expect:**
1. Script will scan all 3 discs
2. Show summary: X episodes, Y extras, Z discarded per disc
3. Display episode mapping preview:
   - S01E01 ← Avatar_The_Last_Airbender_Disc1_t00.mkv
   - S01E02 ← Avatar_The_Last_Airbender_Disc1_t10.mkv
   - ... (sequentially across all discs)
4. List all extras (preserving original filenames)
5. Ask for confirmation: "Proceed with remuxing? [Y/n]:"

**At this point: Type `n` to abort and review the mapping**

### 5. If Mapping Looks Good, Run for Real
```bash
~/scripts/organize-and-remux-tv.sh "Avatar The Last Airbender" 01
# Review the mapping again
# Type `Y` to proceed with remuxing
```

### 6. Check Output
```bash
# View the output directory
tree /mnt/storage/media/staging/2-remuxed/tv/Avatar_The_Last_Airbender/Season_01/
```

Expected output:
```
Season_01/
├── S01E01.mkv
├── S01E02.mkv
├── S01E03.mkv
├── ...
└── extras/
    ├── Avatar_The_Last_Airbender_Disc2_t17.mkv
    ├── Avatar_The_Last_Airbender_Disc2_t19.mkv
    ├── Avatar_The_Last_Airbender_S01_Disc3_t09.mkv
    └── ...
```

### 7. Verify a Few Files
```bash
# Check episode info
mediainfo /mnt/storage/media/staging/2-remuxed/tv/Avatar_The_Last_Airbender/Season_01/S01E01.mkv | grep -E "Duration|Audio|Text"

# Check file was remuxed (should only have eng/bul tracks)
mkvmerge -J /mnt/storage/media/staging/2-remuxed/tv/Avatar_The_Last_Airbender/Season_01/S01E01.mkv | jq '.tracks[] | select(.type == "audio" or .type == "subtitles") | {type, language}'
```

---

## Testing Different Scenarios

### Test Starting at Different Episode Number
```bash
# If you want to start at E05 instead of E01
~/scripts/organize-and-remux-tv.sh "Avatar The Last Airbender" 01 5
```

### Test with Show That Has No Extras
```bash
# Check if Cosmos has any extras
tree -L 2 /mnt/storage/media/staging/1-ripped/tv/Cosmos_A_Spacetime_Odyssey/

# Run script (should work fine with no extras/ subdirectories)
~/scripts/organize-and-remux-tv.sh "Cosmos A Spacetime Odyssey" 01
```

---

## What Changed from Old Script

### Old Workflow (Interactive)
1. Script scans all MKV files
2. **You manually identify extras** via prompts
3. **You name each extra** individually
4. Script remuxes based on your input

### New Workflow (Trusts Manual Pre-Organization)
1. **You organize files first** (already done for Avatar):
   - Main episodes → stay in disc root
   - Extras → move to `extras/` subdirectory
   - Junk → move to `discarded/` subdirectory
2. Script automatically detects organization
3. Script remuxes everything (no prompts needed)
4. Extras preserve original filenames

---

## Troubleshooting

### "No episode files found in disc root directories!"
- Check that you have MKV files in the disc root (not all in subdirectories)
- Verify the disc naming pattern matches `S##_Disc*`

### "No discs found for Season XX"
- Check the show name spelling: `~/scripts/organize-and-remux-tv.sh "Show Name" 01`
- Verify the season number format: `S01_Disc1` (not `S1_Disc1`)

### Script shows wrong number of episodes
- Files in `discarded/` subdirectory should be ignored
- Only files in disc root should be counted as episodes
- Files in `extras/` subdirectory should be listed separately

### Remuxing fails for some files
- Check if the file is corrupted: `mkvmerge -J <file.mkv>`
- Verify the file has eng/bul tracks (script filters for these)

---

## Next Steps After Testing

If the script works correctly:

1. **Continue with Avatar**:
   - Process remaining seasons (if you have them)
   - Optionally transcode with `transcode-queue.sh`

2. **Process other shows**:
   - Manually organize disc directories first
   - Run script for each season

3. **Later in pipeline**:
   - Use FileBot to add episode titles
   - Move to final library location

---

## Questions to Validate

- [ ] Does the script correctly identify episodes vs extras vs discarded?
- [ ] Are episodes numbered sequentially across all discs?
- [ ] Do extras preserve their original filenames?
- [ ] Are only eng/bul audio/subtitle tracks kept?
- [ ] Does the script handle discs with no extras/ subdirectory?
- [ ] Can you specify a custom starting episode number?

---

**Good luck testing! Let me know if you hit any issues or if the workflow feels right.**
