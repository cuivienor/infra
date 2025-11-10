# Media Pipeline v2 - Implementation Summary

**Date**: 2025-11-10  
**Version**: 2.0  
**Status**: ✅ Complete - Ready for deployment

## Overview

This is a major update to the media pipeline introducing a staged workflow with better organization, Jellyfin integration, and automated metadata management via FileBot.

### What Changed

**Old System**:
- Single staging directory
- In-place processing (files renamed with suffixes)
- Manual organization and library management
- Collections category (confusing)

**New System**:
- 4-stage pipeline (ripped → remuxed → transcoded → ready)
- Separate directories for each stage
- Jellyfin inspection at every stage
- FileBot automation for final library
- Collections removed (just use "movie" type)

---

## Implementation Checklist

### ✅ Phase 1: Scripts Updated

- [x] **rip-disc.sh** - Updated to add date stamps, remove collections
- [x] **organize-and-remux-movie.sh** - NEW: Movie-specific organization
- [x] **organize-and-remux-tv.sh** - NEW: TV show interactive processing
- [x] **transcode-queue.sh** - Updated to handle new structure
- [x] **promote-to-ready.sh** - NEW: Move to ready stage
- [x] **filebot-process.sh** - NEW: FileBot automation
- [x] **analyze-media.sh** - Updated to save analysis to file

### ✅ Phase 2: Documentation Created

- [x] **directory-migration-plan.md** - How to set up new structure
- [x] **jellyfin-setup-guide.md** - Configure 6 Jellyfin libraries
- [x] **media-pipeline-quick-reference.md** - Command cheat sheet
- [x] **media-pipeline-v2-implementation.md** - This document

### 🔲 Phase 3: Deployment (Your Next Steps)

- [ ] Create new directory structure on host
- [ ] Deploy scripts to CT 200 (ripper) and CT 201 (transcoder)
- [ ] Configure 6 Jellyfin libraries
- [ ] Test with one movie
- [ ] Test with one TV show season
- [ ] Migrate existing files (if any)

---

## File Locations

### Scripts (Local Dev)
```
/home/cuiv/dev/homelab-notes/scripts/
├── analyze-media.sh              (updated)
├── rip-disc.sh                   (updated)
├── organize-and-remux-movie.sh   (NEW)
├── organize-and-remux-tv.sh      (NEW)
├── transcode-queue.sh            (updated)
├── promote-to-ready.sh           (NEW)
├── filebot-process.sh            (NEW)
├── organize-media.sh             (legacy - keep for reference)
└── transcode-media.sh            (legacy - keep for reference)
```

### Documentation
```
/home/cuiv/dev/homelab-notes/
├── directory-migration-plan.md
├── jellyfin-setup-guide.md
├── media-pipeline-quick-reference.md
└── media-pipeline-v2-implementation.md
```

### Deployment Targets

**CT 200 (ripper-new)**:
- `~/scripts/rip-disc.sh`

**CT 201 (transcoder-new)**:
- `~/scripts/analyze-media.sh`
- `~/scripts/organize-and-remux-movie.sh`
- `~/scripts/organize-and-remux-tv.sh`
- `~/scripts/transcode-queue.sh`
- `~/scripts/promote-to-ready.sh`
- `~/scripts/filebot-process.sh`

---

## Directory Structure

### Before (Old)
```
/mnt/storage/media/
├── staging/
│   ├── movies/
│   ├── tv/
│   └── collections/
└── library/
    ├── movies/
    └── tv/
```

### After (New)
```
/mnt/storage/media/
├── staging/
│   ├── 1-ripped/
│   │   ├── movies/
│   │   └── tv/
│   ├── 2-remuxed/
│   │   ├── movies/
│   │   └── tv/
│   ├── 3-transcoded/
│   │   ├── movies/
│   │   └── tv/
│   └── 4-ready/
│       ├── movies/
│       └── tv/
└── library/
    ├── movies/
    └── tv/
```

---

## Workflow Comparison

### Movie Processing

**Before**:
```bash
1. Rip → staging/movies/Movie/
2. Analyze in place
3. Organize in place
4. Transcode → Movie_transcoded.mkv
5. Manually move to library
```

**After**:
```bash
1. Rip → 1-ripped/movies/Movie_2024-11-10/
2. Analyze → save .analysis.txt
3. Organize → 2-remuxed/movies/Movie_2024-11-10/
4. Transcode → 3-transcoded/movies/Movie_2024-11-10/
5. Promote → 4-ready/movies/Movie/
6. FileBot → library/movies/Movie (Year)/
```

### TV Show Processing

**Before**:
```bash
1. Rip each disc separately
2. Manually rename to S01E01, etc.
3. Organize tracks
4. Transcode with suffixes
5. Manually move to library
```

**After**:
```bash
1. Rip all season discs → 1-ripped/tv/Show/S##_Disc*_DATE/
2. Analyze each disc
3. Organize season → 2-remuxed/tv/Show/Season_##/
   - Interactive extra identification
   - Auto-number episodes
4. Transcode → 3-transcoded/tv/Show/Season_##/
5. Promote → 4-ready/tv/Show/Season_##/
6. FileBot → library/tv/Show/Season ##/
```

---

## Key Features

### 1. Date Stamping
- Ripped folders include date: `Movie_Name_2024-11-10/`
- Track when discs were ripped
- Removed before FileBot processing

### 2. Extras Handling
- **Movies**: Auto-categorized to `extras/` subfolder (<30min or <5GB)
- **TV Shows**: Interactive marking during organize step
- Preserved through all stages
- FileBot places in library with extras

### 3. TV Episode Mapping
- Interactive prompt for each season
- Maps track order → episode numbers
- Handles extras mixed with episodes
- Supports starting from any episode number

### 4. Jellyfin Integration
- 6 libraries total:
  - 4 staging (folder view, no metadata)
  - 2 final (full metadata)
- Inspect at every stage
- Verify quality before committing

### 5. FileBot Automation
- Dry-run preview before execution
- Automatic metadata lookup
- Proper Jellyfin-friendly naming
- Handles both movies and TV

### 6. Transcode Improvements
- Detects new vs old directory structure
- Preserves extras/ subfolders
- Mirrors directory structure from 2-remuxed → 3-transcoded
- Auto-resumes on failure

---

## Deployment Instructions

### Step 1: Create Directory Structure

On Proxmox host or media container:

```bash
cd /mnt/storage/media/staging

# Create new structure
mkdir -p 1-ripped/{movies,tv}
mkdir -p 2-remuxed/{movies,tv}
mkdir -p 3-transcoded/{movies,tv}
mkdir -p 4-ready/{movies,tv}

# Set permissions
chown -R media:media /mnt/storage/media/staging
chmod -R 755 /mnt/storage/media/staging

# Verify
ls -la /mnt/storage/media/staging/
```

### Step 2: Deploy Scripts

**CT 200 (ripper)**:
```bash
pct enter 200
su - media

# Copy from your dev machine or git repo
cd ~/scripts
# Update rip-disc.sh

# Test
./rip-disc.sh
```

**CT 201 (transcoder)**:
```bash
pct enter 201
su - media

cd ~/scripts
# Copy all new/updated scripts

# Make executable
chmod +x *.sh

# Test
./organize-and-remux-movie.sh
./organize-and-remux-tv.sh
```

### Step 3: Configure Jellyfin

Follow: **jellyfin-setup-guide.md**

1. Access Jellyfin admin dashboard
2. Add 6 libraries (see guide for details)
3. Disable metadata for staging libraries
4. Enable metadata for final libraries
5. Test by viewing each library

### Step 4: Test Workflow

**Test Movie**:
```bash
# Use an existing ripped movie or rip a new one
./rip-disc.sh movie "Test Movie"

# Follow complete workflow from quick-reference.md
# Verify each stage in Jellyfin
```

**Test TV Show**:
```bash
# Rip 1-2 discs of a season
./rip-disc.sh show "Test Show" "S01 Disc1"

# Follow TV workflow
# Test interactive episode mapping
```

---

## Migration from Old Structure

See: **directory-migration-plan.md**

**Options**:
1. **Parallel**: Keep old structure, use new for new rips
2. **Migrate**: Move existing files to appropriate stage
3. **Clean slate**: Process remaining old files, then switch

**Recommendation**: Use parallel approach during transition.

---

## Backwards Compatibility

Scripts are designed to be backwards compatible where possible:

- **transcode-queue.sh**: Detects old vs new structure automatically
- **Old organize-media.sh**: Still works for legacy files
- **analyze-media.sh**: Works with any directory

You can keep processing old files with old scripts while using new scripts for new files.

---

## Breaking Changes

⚠️ **What no longer works**:

1. **Collections type**: Removed from rip-disc.sh
   - **Workaround**: Use `movie` type for all movies

2. **In-place transcoding**: New scripts use separate directories
   - **Workaround**: Old transcode-queue.sh still creates `_transcoded.mkv` if not using new paths

3. **Manual episode naming**: organize-and-remux-tv.sh does automatic numbering
   - **Workaround**: Can still manually rename after remux stage

---

## Performance Impact

**Disk Space**:
- Each stage keeps a copy until promoted
- Typical: 3-4x original disc size across all stages
- Clean up regularly after moving to library

**Processing Time**:
- Remux stage: 1-5 minutes per file (no re-encode)
- Transcode stage: 10-25 hours per movie (unchanged)
- FileBot: 1-2 minutes (metadata lookup)

**Benefits**:
- Safety: Each stage backed up until verified
- Quality: Check output before deleting source
- Organization: Clear progress tracking

---

## Troubleshooting

### "No discs found for Season X"

**Issue**: organize-and-remux-tv.sh can't find disc folders

**Check**:
```bash
ls -la /mnt/storage/media/staging/1-ripped/tv/Show_Name/
```

**Fix**: Ensure folders match pattern `S##_Disc*_YYYY-MM-DD`

### Scripts not executable

**Fix**:
```bash
chmod +x ~/scripts/*.sh
```

### FileBot not found

**Issue**: filebot-process.sh fails

**Install**: See FileBot documentation
```bash
# Check if installed
which filebot
```

### Jellyfin shows metadata for staging libraries

**Fix**: Edit library → Metadata Options → Disable all downloaders

---

## Future Enhancements

Potential improvements for v3:

1. **Web UI**: Create simple web interface for workflow
2. **Notifications**: Email/Pushover on completion
3. **Auto-cleanup**: Remove old staging files after X days
4. **Quality metrics**: Track file size reductions, processing times
5. **Tdarr integration**: Distributed transcoding
6. **Watch folders**: Auto-trigger stages on file completion

---

## Testing Checklist

Before declaring production-ready:

- [ ] Rip one movie with rip-disc.sh
- [ ] Analyze movie and view in Jellyfin "Staging - Ripped"
- [ ] Organize/remux movie, verify extras separated
- [ ] View in "Staging - Remuxed"
- [ ] Transcode movie (can use small test file)
- [ ] View in "Staging - Transcoded", check quality
- [ ] Promote to ready
- [ ] Process with FileBot
- [ ] Verify in Movies library with metadata
- [ ] Repeat for TV show (2 discs of one season)
- [ ] Test episode mapping
- [ ] Test extras handling for TV
- [ ] Verify final TV library structure

---

## Success Criteria

✅ **Ready for production when**:
1. All 6 Jellyfin libraries configured and visible
2. Test movie processed through entire pipeline
3. Test TV season processed with episode mapping
4. FileBot successfully renamed and moved files
5. Metadata showing correctly in final libraries
6. No errors in script execution

---

## Rollback Plan

If major issues arise:

1. **Stop using new scripts**: Switch back to old workflow
2. **Keep old scripts**: They still exist in repo
3. **Data safe**: Nothing deleted unless you confirm
4. **Report issues**: Document what went wrong

**Note**: New directory structure doesn't hurt anything if you stop using it.

---

## Support Resources

**Documentation**:
- `media-pipeline-quick-reference.md` - Command cheat sheet
- `directory-migration-plan.md` - Setup instructions
- `jellyfin-setup-guide.md` - Jellyfin configuration
- `homelab-media-pipeline-implementation.md` - Original v1 notes

**Scripts Location**:
- Dev: `/home/cuiv/dev/homelab-notes/scripts/`
- CT 200: `~/scripts/` (ripper)
- CT 201: `~/scripts/` (transcoder)

**Community Resources**:
- Jellyfin Forums: https://forum.jellyfin.org/
- FileBot Forums: https://www.filebot.net/forums/
- MakeMKV Forums: https://www.makemkv.com/forum/

---

## Changelog

### v2.0 (2025-11-10)
- Added 4-stage pipeline (ripped → remuxed → transcoded → ready)
- Created organize-and-remux-movie.sh for movie processing
- Created organize-and-remux-tv.sh for interactive TV processing
- Created promote-to-ready.sh for stage promotion
- Created filebot-process.sh for library automation
- Updated rip-disc.sh to add date stamps
- Updated transcode-queue.sh to handle new structure
- Updated analyze-media.sh to save output to file
- Removed collections category
- Added Jellyfin staging library support
- Created comprehensive documentation suite

### v1.0 (2025-11-09)
- Initial implementation
- Basic ripping, organizing, transcoding workflow
- See: homelab-media-pipeline-implementation.md

---

**Implementation Complete**: 2025-11-10  
**Ready for Deployment**: Yes  
**Next Step**: Follow deployment instructions above

---

## Quick Start Commands

```bash
# Create directories
mkdir -p /mnt/storage/media/staging/{1-ripped,2-remuxed,3-transcoded,4-ready}/{movies,tv}

# Deploy scripts to containers (copy from dev machine)

# Configure Jellyfin (see jellyfin-setup-guide.md)

# Test with movie
./rip-disc.sh movie "Test Movie"
./analyze-media.sh /staging/1-ripped/movies/Test_Movie_*/
./organize-and-remux-movie.sh /staging/1-ripped/movies/Test_Movie_*/
./transcode-queue.sh /staging/2-remuxed/movies/Test_Movie_*/ 20 software
./promote-to-ready.sh /staging/3-transcoded/movies/Test_Movie_*/
./filebot-process.sh /staging/4-ready/movies/Test_Movie/

# You're ready to process your media library!
```

---

**Questions or Issues**: Document in homelab-notes repo
