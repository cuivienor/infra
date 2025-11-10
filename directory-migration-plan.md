# Directory Structure Migration Plan

**Date**: 2025-11-10  
**Purpose**: Migrate from old staging structure to new numbered staging workflow

## Current Structure

```
/mnt/storage/media/staging/
├── movies/
├── tv/
└── collections/  (to be removed)
```

## New Structure

```
/mnt/storage/media/staging/
├── 1-ripped/      # Fresh from disc
│   ├── movies/
│   └── tv/
├── 2-remuxed/     # After track filtering
│   ├── movies/
│   └── tv/
├── 3-transcoded/  # After transcoding
│   ├── movies/
│   └── tv/
└── 4-ready/       # Ready for FileBot
    ├── movies/
    └── tv/

/mnt/storage/media/library/  # Final library (no change)
├── movies/
└── tv/
```

## Migration Steps

### Step 1: Create New Directory Structure

Run these commands on your Proxmox host or in the appropriate container:

```bash
# Create new staging directories
mkdir -p /mnt/storage/media/staging/1-ripped/movies
mkdir -p /mnt/storage/media/staging/1-ripped/tv
mkdir -p /mnt/storage/media/staging/2-remuxed/movies
mkdir -p /mnt/storage/media/staging/2-remuxed/tv
mkdir -p /mnt/storage/media/staging/3-transcoded/movies
mkdir -p /mnt/storage/media/staging/3-transcoded/tv
mkdir -p /mnt/storage/media/staging/4-ready/movies
mkdir -p /mnt/storage/media/staging/4-ready/tv

# Create library directories if they don't exist
mkdir -p /mnt/storage/media/library/movies
mkdir -p /mnt/storage/media/library/tv

# Set proper permissions
chown -R media:media /mnt/storage/media/staging
chown -R media:media /mnt/storage/media/library
```

### Step 2: Handle Existing Files

**If you have files currently being processed:**

#### Option A: Continue with old structure until done
- Keep using current scripts for in-progress work
- New rips use new structure
- Gradually migrate as you finish old batches

#### Option B: Move existing files to new structure

```bash
# Identify what stage your files are in
cd /mnt/storage/media/staging

# For files that are just ripped (not yet organized):
# Move to 1-ripped with date stamp
mv movies/Some_Movie /mnt/storage/media/staging/1-ripped/movies/Some_Movie_$(date +%Y-%m-%d)

# For files already organized/remuxed:
# Move to 2-remuxed
mv movies/Some_Movie /mnt/storage/media/staging/2-remuxed/movies/Some_Movie_$(date +%Y-%m-%d)

# For transcoded files:
# Move to 3-transcoded
mv movies/Some_Movie /mnt/storage/media/staging/3-transcoded/movies/Some_Movie_$(date +%Y-%m-%d)
```

### Step 3: Remove Old Directories (after migration)

**Only after all files are migrated or processed:**

```bash
# Check directories are empty
ls -la /mnt/storage/media/staging/movies/
ls -la /mnt/storage/media/staging/tv/
ls -la /mnt/storage/media/staging/collections/

# Remove if empty
rmdir /mnt/storage/media/staging/movies
rmdir /mnt/storage/media/staging/tv
rmdir /mnt/storage/media/staging/collections
```

## Updated Script Locations

### Ripper Container (CT 200)

Deploy updated scripts:

```bash
# SSH or pct enter to ripper container
pct enter 200
su - media

# The rip-disc.sh script has been updated to use new structure
# Copy from your notes repo
cd ~/scripts
# Ensure you have the latest version that uses 1-ripped/
```

### Transcoder Container (CT 201)

Deploy new scripts:

```bash
pct enter 201
su - media

cd ~/scripts

# You should have:
# - analyze-media.sh (updated)
# - organize-and-remux-movie.sh (NEW)
# - organize-and-remux-tv.sh (NEW)
# - transcode-queue.sh (updated)
# - promote-to-ready.sh (NEW)
# - filebot-process.sh (NEW)
```

## Workflow Changes

### Old Workflow
```
1. Rip → staging/movies/Movie_Name/
2. Analyze in same folder
3. Organize (track filtering) in place
4. Transcode → Movie_Name_t00_transcoded.mkv
5. Manually move to library
```

### New Workflow
```
1. Rip → staging/1-ripped/movies/Movie_Name_2024-11-10/
2. Analyze in 1-ripped
3. Organize → staging/2-remuxed/movies/Movie_Name_2024-11-10/
4. Transcode → staging/3-transcoded/movies/Movie_Name_2024-11-10/
5. Promote → staging/4-ready/movies/Movie_Name/
6. FileBot → library/movies/Movie Name (Year)/
```

## Testing the New Structure

### Test with a single movie:

```bash
# 1. Rip a test disc (or use existing files)
./rip-disc.sh movie "Test Movie"
# Verify: /staging/1-ripped/movies/Test_Movie_2024-11-10/

# 2. Analyze
./analyze-media.sh /staging/1-ripped/movies/Test_Movie_2024-11-10/
# Verify: .analysis.txt created

# 3. Organize & remux
./organize-and-remux-movie.sh /staging/1-ripped/movies/Test_Movie_2024-11-10/
# Verify: /staging/2-remuxed/movies/Test_Movie_2024-11-10/

# 4. Transcode
./transcode-queue.sh /staging/2-remuxed/movies/Test_Movie_2024-11-10/ 20 software
# Verify: /staging/3-transcoded/movies/Test_Movie_2024-11-10/

# 5. Promote
./promote-to-ready.sh /staging/3-transcoded/movies/Test_Movie_2024-11-10/
# Verify: /staging/4-ready/movies/Test_Movie/

# 6. FileBot (if installed)
./filebot-process.sh /staging/4-ready/movies/Test_Movie/
# Verify: /library/movies/Test Movie (Year)/
```

## Rollback Plan

If issues arise with new structure:

1. **Scripts are backwards compatible**: transcode-queue.sh detects old vs new paths
2. **Old scripts still exist**: Keep backup of original scripts
3. **Data not lost**: Files moved, not deleted
4. **Manual moves**: Can always manually organize files

## Next Steps After Migration

1. **Update Jellyfin libraries** (see jellyfin-setup-guide.md)
2. **Test full workflow** with one movie and one TV show
3. **Document any issues** encountered
4. **Begin processing backlog** with new workflow

## Notes

- **Date stamps**: Added automatically by rip-disc.sh for tracking
- **Collections removed**: Just use "movie" type for all movies
- **Extras handling**: Automatic categorization based on duration/size
- **TV episodes**: Interactive mapping during organize-and-remux-tv.sh

---

**Status**: Ready to implement  
**Risk**: Low (non-destructive, can rollback)  
**Time**: 10-15 minutes for setup, varies for file migration
