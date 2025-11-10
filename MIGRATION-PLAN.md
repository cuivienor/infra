# Staging Migration Plan

**Date**: 2025-11-10  
**Current State**: Mixed old and new structure

## Current Files Analysis

### Movies (Raw Rips - Need to Move to 1-ripped)

| Old Folder | Files | New Location | Notes |
|------------|-------|--------------|-------|
| `Dragon2/` | 17 MKV files | `1-ripped/movies/How_To_Train_Your_Dragon_2_2024-11-10/` | Raw rip, needs analysis |
| `LionKing/` | 6 MKV files (including final.mkv) | `1-ripped/movies/The_Lion_King_2024-11-10/` | Has a "final.mkv" - may need review |
| `Matrix/` | 6 MKV files | `1-ripped/movies/The_Matrix_2024-11-10/` | Regular Blu-ray rip |
| `Matrix-UHD/` | 4 MKV files | `1-ripped/movies/The_Matrix_UHD_2024-11-10/` | 4K UHD rip (different quality) |

### Movies (Partially Processed - Dragon)

**Current State**:
```
Dragon/
├── How To Train Your Dragon.mkv                  (remuxed original)
├── How To Train Your Dragon - Extra 1.mkv        (remuxed original)
├── How To Train Your Dragon - Extra 2.mkv        (remuxed original)
├── How To Train Your Dragon_transcoded.mkv       (transcoded)
├── How To Train Your Dragon - Extra 1_transcoded.mkv
└── How To Train Your Dragon - Extra 2_transcoded.mkv
```

**New Structure**:
- Originals → `2-remuxed/movies/How_To_Train_Your_Dragon_2024-11-10/`
  - Main feature in root
  - Extras in `extras/` subfolder
- Transcoded → `3-transcoded/movies/How_To_Train_Your_Dragon_2024-11-10/`
  - Same structure (with `extras/`)
  - Remove `_transcoded` suffix

### TV Shows (Raw Rips - Cosmos)

**Current State**:
```
Cosmos/
├── COSMOS- A SpaceTime Odyssey, Season 1 Disc 1_t00.mkv
├── COSMOS- A SpaceTime Odyssey, Season 1 Disc 1_t01.mkv
├── ... (4 files from Disc 1)
├── COSMOS- A SpaceTime Odyssey, Season 1 Disc 2_t00.mkv
├── ... (4 files from Disc 2)
├── COSMOS- A SpaceTime Odyssey, Season 1 Disc 3_t00.mkv
├── ... (4 files from Disc 3)
├── COSMOS- A SpaceTime Odyssey, Season 1 Disc 4_t00.mkv
└── ... (15 files from Disc 4!)
```

**New Structure**:
```
1-ripped/tv/Cosmos_A_Spacetime_Odyssey/
├── S01_Disc1_2024-11-10/
│   └── (4 files)
├── S01_Disc2_2024-11-10/
│   └── (4 files)
├── S01_Disc3_2024-11-10/
│   └── (4 files)
└── S01_Disc4_2024-11-10/
    └── (15 files - probably has extras)
```

**Note**: Disc 4 has 15 files - probably includes extras/bonus content. Will need analysis.

### TV Shows (Partially Processed - Avatar)

**Current State**:
```
tv/Avatar_The_Last_Airbender/
├── Season_1_Disc_1/
│   ├── S01E01.mkv ... S01E19.mkv  (✓ Already renamed)
└── Season_1_Disc_2/
    └── !ERRtemplate_t00.mkv ... t19.mkv  (✗ Bad names)
```

**Issues**:
1. Disc 1: Already renamed to S01E##, but these are raw rips (should be in 1-ripped)
2. Disc 2: Has `!ERRtemplate` names (MakeMKV error - template not configured)

**New Structure**:
```
1-ripped/tv/Avatar_The_Last_Airbender/
├── S01_Disc1_2024-11-10/
│   └── S01E01.mkv ... S01E19.mkv  (keep as-is for now)
└── S01_Disc2_2024-11-10/
    └── Avatar_The_Last_Airbender_t00.mkv ... t19.mkv  (fixed names)
```

**Note**: Disc 1 files will keep S01E## names (easier to track), but they're raw rips. When you run organize-and-remux-tv.sh, you'll map them properly.

---

## Migration Script Actions

The `migrate-staging.sh` script will:

### 1. Movies - Raw Rips
- **Move** (not copy) all files to `1-ripped/movies/[Name]_2024-11-10/`
- Add today's date stamp
- Clean up old directories

### 2. Movies - Dragon (Partially Processed)
- **Split** into two stages:
  - Originals → `2-remuxed/movies/How_To_Train_Your_Dragon_2024-11-10/`
    - Main feature in root
    - Extras in `extras/` subfolder
  - Transcoded → `3-transcoded/movies/How_To_Train_Your_Dragon_2024-11-10/`
    - Mirror structure
    - Remove `_transcoded` suffix

### 3. TV Shows - Cosmos
- **Organize** by disc into `1-ripped/tv/Cosmos_A_Spacetime_Odyssey/`
- Create separate folders for each disc
- Add date stamps

### 4. TV Shows - Avatar
- **Move** both discs to `1-ripped/tv/Avatar_The_Last_Airbender/`
- **Fix** !ERRtemplate names on Disc 2 → `Avatar_The_Last_Airbender_t##.mkv`
- Keep Disc 1 names as-is (already S01E##)

---

## After Migration - Next Steps

### 1-ripped/movies/

Each movie needs analysis and processing:

```bash
# Analyze each movie
./analyze-media.sh /staging/1-ripped/movies/How_To_Train_Your_Dragon_2_2024-11-10/
./analyze-media.sh /staging/1-ripped/movies/The_Lion_King_2024-11-10/
./analyze-media.sh /staging/1-ripped/movies/The_Matrix_2024-11-10/
./analyze-media.sh /staging/1-ripped/movies/The_Matrix_UHD_2024-11-10/

# Review in Jellyfin "Staging - Ripped" library
# Identify duplicates/extras

# Organize & remux
./organize-and-remux-movie.sh /staging/1-ripped/movies/How_To_Train_Your_Dragon_2_2024-11-10/
# ... repeat for each
```

### 1-ripped/tv/

TV shows need full season organization:

```bash
# Cosmos - organize all 4 discs into Season 01
./organize-and-remux-tv.sh "Cosmos A Spacetime Odyssey" 01
# Interactive: mark extras (Disc 4 likely has them)
# Map episodes in order

# Avatar - organize both discs into Season 01
./organize-and-remux-tv.sh "Avatar The Last Airbender" 01
# Disc 1 will show S01E## (already numbered)
# Disc 2 will show as track numbers
# You'll confirm/adjust episode mapping
```

### 3-transcoded/movies/

Dragon is already transcoded and ready:

```bash
# Review quality in Jellyfin "Staging - Transcoded" library
# If satisfied, promote to ready:
./promote-to-ready.sh /staging/3-transcoded/movies/How_To_Train_Your_Dragon_2024-11-10/

# Then FileBot to library:
./filebot-process.sh /staging/4-ready/movies/How_To_Train_Your_Dragon/
```

---

## Special Cases to Review

### 1. Lion King - "final.mkv"

The LionKing folder has a file called `final.mkv`. This suggests you may have:
- Already identified which track is the main movie
- Renamed it manually

**Action**: After migration, check if `final.mkv` is the one you want to keep, delete the others.

### 2. Matrix - Two Versions

You have:
- `Matrix/` - Regular Blu-ray (6 files)
- `Matrix-UHD/` - 4K UHD (4 files)

**Question**: Do you want both versions, or just the 4K?

If just 4K:
- Process Matrix-UHD only
- Delete Matrix folder after migration

If both:
- Process separately
- FileBot will handle naming (one will be "The Matrix (1999)" and UHD might be "The Matrix (1999) 4K")

### 3. Avatar Disc 1 - Pre-renamed

Disc 1 already has S01E## names. This means either:
- You manually renamed them, OR
- A previous script renamed them

**Impact**: When you run organize-and-remux-tv.sh, the script will see these as track numbers. You'll need to confirm episode mapping.

**Alternative**: Since they're already numbered correctly, you could manually move them to 2-remuxed instead of going through organize again.

### 4. Cosmos Disc 4 - Extra Content

Disc 4 has 15 files vs 4 files on other discs. Likely includes:
- 3-4 episodes
- 11+ extras/bonus features

**Action**: When running organize-and-remux-tv.sh, you'll mark the extras interactively.

---

## Pre-Migration Checklist

Before running migrate-staging.sh:

- [ ] **Backup**: Ensure you have backups (optional, but safe)
- [ ] **Free Space**: Check you have enough space for reorganization
  ```bash
  df -h /mnt/storage
  ```
- [ ] **Review Script**: Read through migrate-staging.sh to understand actions
- [ ] **Jellyfin**: Configure staging libraries if not already done
- [ ] **Scripts Deployed**: Ensure all new scripts are on CT 201

---

## Running the Migration

### Step 1: Review Current State

```bash
cd /mnt/storage/media/staging
tree -L 2
```

### Step 2: Run Migration Script

```bash
# Copy script to container (if not already there)
# Then run:
./migrate-staging.sh
```

The script will:
1. Show preview of what will be migrated
2. Ask for confirmation
3. Move all files to new locations
4. Show summary of new structure
5. Print next steps

### Step 3: Verify New Structure

```bash
cd /mnt/storage/media/staging
tree -L 3 1-ripped/
tree -L 3 2-remuxed/
tree -L 3 3-transcoded/
```

### Step 4: Configure Jellyfin (if not done)

Add/verify 4 staging libraries pointing to:
- `/mnt/storage/media/staging/1-ripped`
- `/mnt/storage/media/staging/2-remuxed`
- `/mnt/storage/media/staging/3-transcoded`
- `/mnt/storage/media/staging/4-ready`

---

## Rollback Plan

If something goes wrong:

**The script MOVES files**, so they're not lost, just relocated.

To undo manually:
1. Move folders back from `1-ripped/movies/` to root of staging
2. Rename folders (remove date stamps)
3. Restore old structure

**Better**: Test with one folder first:
- Comment out all but one movie in the migration script
- Run and verify
- Then run full migration

---

## Questions to Answer Before Migration

1. **Matrix versions**: Keep both regular and UHD, or just UHD?
2. **Lion King**: Is `final.mkv` the one you want to keep?
3. **Dragon transcodes**: Are you happy with the quality? Ready to promote to library?
4. **Avatar Disc 1**: Want to keep pre-renamed S01E## or reset to track numbers?

---

**Status**: Ready to run  
**Risk**: Low (files moved, not deleted)  
**Time**: ~1 minute  
**Reversible**: Yes (manual undo if needed)
