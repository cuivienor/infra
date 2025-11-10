# Jellyfin Library Setup Guide

**Date**: 2025-11-10  
**Purpose**: Configure Jellyfin libraries for the new staged media workflow

## Overview

You'll create **6 Jellyfin libraries total**:
- 4 staging libraries (folder view, no metadata)
- 2 final libraries (with full metadata)

This allows you to inspect files at each stage of processing in Jellyfin before finalizing them in your main library.

---

## Library Configuration

### 1. Staging - Ripped

**Purpose**: View freshly ripped files directly from disc

**Settings**:
- **Display Name**: `Staging - Ripped`
- **Content Type**: `Folders`
- **Folder Path**: `/mnt/storage/media/staging/1-ripped`
- **Metadata Options**:
  - ❌ Disable all metadata downloaders
  - ❌ Disable all image fetchers
  - ❌ Disable automatic refresh
  - ✅ Enable "Real-Time Monitoring" (optional)

**Why**: You want to see raw files exactly as ripped, with original MakeMKV names like `Movie_Name_t00.mkv`. No metadata fetching means Jellyfin won't try to guess what they are.

---

### 2. Staging - Remuxed

**Purpose**: View files after track filtering (eng/bul only)

**Settings**:
- **Display Name**: `Staging - Remuxed`
- **Content Type**: `Folders`
- **Folder Path**: `/mnt/storage/media/staging/2-remuxed`
- **Metadata Options**:
  - ❌ Disable all metadata downloaders
  - ❌ Disable all image fetchers
  - ❌ Disable automatic refresh
  - ✅ Enable "Real-Time Monitoring" (optional)

**Why**: Verify track filtering worked. Files are organized (extras in subfolders for movies, episodes numbered for TV) but still use generic names.

---

### 3. Staging - Transcoded

**Purpose**: Quality check transcoded files before final promotion

**Settings**:
- **Display Name**: `Staging - Transcoded`
- **Content Type**: `Folders`
- **Folder Path**: `/mnt/storage/media/staging/3-transcoded`
- **Metadata Options**:
  - ❌ Disable all metadata downloaders
  - ❌ Disable all image fetchers
  - ❌ Disable automatic refresh
  - ✅ Enable "Real-Time Monitoring" (optional)

**Why**: Compare transcoded vs. original quality. Play first few minutes to verify encoding didn't introduce artifacts.

---

### 4. Staging - Ready

**Purpose**: Final review before FileBot processing

**Settings**:
- **Display Name**: `Staging - Ready`
- **Content Type**: `Folders`
- **Folder Path**: `/mnt/storage/media/staging/4-ready`
- **Metadata Options**:
  - ❌ Disable all metadata downloaders
  - ❌ Disable all image fetchers
  - ❌ Disable automatic refresh
  - ✅ Enable "Real-Time Monitoring" (optional)

**Why**: Last chance to review before FileBot renames and moves to library. Date stamps removed, ready for metadata lookup.

---

### 5. Movies (Final Library)

**Purpose**: Your main movie library with full metadata

**Settings**:
- **Display Name**: `Movies`
- **Content Type**: `Movies`
- **Folder Path**: `/mnt/storage/media/library/movies`
- **Metadata Options**:
  - ✅ Enable "TheMovieDb" (primary)
  - ✅ Enable "The Open Movie Database"
  - ✅ Enable all image fetchers
  - ✅ Enable automatic refresh
  - ✅ Enable "Real-Time Monitoring"
- **NFO Settings**:
  - Set to "Local" if you want to save metadata locally

**Why**: This is where FileBot places final, properly named movies. Jellyfin fetches all metadata automatically.

---

### 6. TV Shows (Final Library)

**Purpose**: Your main TV library with full metadata

**Settings**:
- **Display Name**: `TV Shows`
- **Content Type**: `TV Shows`
- **Folder Path**: `/mnt/storage/media/library/tv`
- **Metadata Options**:
  - ✅ Enable "TheTVDB" (primary)
  - ✅ Enable "TheMovieDb" (secondary)
  - ✅ Enable all image fetchers
  - ✅ Enable automatic refresh
  - ✅ Enable "Real-Time Monitoring"
- **NFO Settings**:
  - Set to "Local" if you want to save metadata locally

**Why**: Final TV show library. Episodes auto-match with TheTVDB, episode titles and descriptions fetched automatically.

---

## Step-by-Step Setup in Jellyfin

### Access Jellyfin Admin

1. Go to: `http://your-jellyfin-server:8096`
2. Login as admin
3. Click on Dashboard (☰ menu → Dashboard)
4. Go to: **Libraries** section

### Add Each Library

For each library above:

1. Click **Add Media Library**
2. **Content Type**: Select appropriate type (Folders or Movies or TV Shows)
3. **Display Name**: Enter name (e.g., "Staging - Ripped")
4. **Folders**: Click **+** and add the path
5. Click on **Advanced** (optional settings):
   - Set library refresh interval
   - Configure real-time monitoring
6. **Metadata Options**:
   - Scroll down to find metadata downloaders
   - Uncheck all for staging libraries
   - Enable all for final libraries
7. Click **OK** to save

### Verify Libraries

After adding all libraries:

1. Go back to Jellyfin home
2. You should see 6 libraries listed
3. Click into each staging library:
   - Should show folder structure, not metadata
   - Files show with original names
4. Click into Movies/TV Shows:
   - Should be empty initially
   - Will populate as FileBot moves files

---

## Usage Patterns

### Inspecting Ripped Files

1. Navigate to **Staging - Ripped**
2. Browse by folder structure: `movies/Movie_Name_2024-11-10/`
3. Play a file to verify it ripped correctly
4. Use this to identify duplicates (play first 30 seconds)

### Comparing Originals vs Transcoded

1. Open **Staging - Remuxed** in one browser tab
2. Open **Staging - Transcoded** in another tab
3. Play same file from each
4. Compare quality, file size, loading time

### Checking Before FileBot

1. Navigate to **Staging - Ready**
2. Ensure file names are clean
3. Verify folder structure looks correct
4. If anything wrong, can still fix before FileBot

---

## Folder View Tips

When viewing staging libraries (Folders type):

- **Sort by Date**: Click on column headers to sort
- **File Info**: Click on `...` menu → Media Info to see tracks
- **Play inline**: No need to download, streams directly
- **No posters**: Normal - these libraries don't fetch metadata

---

## Expected Directory Structure in Each Library

### Staging - Ripped
```
movies/
└── How_To_Train_Your_Dragon_2024-11-10/
    ├── How_To_Train_Your_Dragon_t00.mkv
    ├── How_To_Train_Your_Dragon_t01.mkv
    └── How_To_Train_Your_Dragon_t02.mkv

tv/
└── Avatar_The_Last_Airbender/
    ├── S01_Disc1_2024-11-10/
    └── S01_Disc2_2024-11-10/
```

### Staging - Remuxed
```
movies/
└── How_To_Train_Your_Dragon_2024-11-10/
    ├── How_To_Train_Your_Dragon_t01.mkv
    └── extras/
        └── How_To_Train_Your_Dragon_t02.mkv

tv/
└── Avatar_The_Last_Airbender/
    └── Season_01/
        ├── S01E01.mkv
        ├── S01E02.mkv
        └── extras/
```

### Staging - Transcoded
```
(mirrors 2-remuxed structure)
```

### Staging - Ready
```
movies/
└── How_To_Train_Your_Dragon/  (date stamp removed)
    ├── How_To_Train_Your_Dragon_t01.mkv
    └── extras/

tv/
└── Avatar_The_Last_Airbender/
    └── Season_01/
        ├── S01E01.mkv
        └── S01E02.mkv
```

### Movies (Final)
```
How to Train Your Dragon (2010)/
├── How to Train Your Dragon (2010).mkv
└── extras/
    └── Behind the Scenes.mkv
```

### TV Shows (Final)
```
Avatar The Last Airbender/
└── Season 01/
    ├── Avatar The Last Airbender - S01E01 - The Boy in the Iceberg.mkv
    ├── Avatar The Last Airbender - S01E02 - The Avatar Returns.mkv
    └── ...
```

---

## Maintenance

### Periodic Cleanup

Staging libraries can accumulate files:

```bash
# After verifying files are in final library, clean staging
# Check staging directories
du -sh /mnt/storage/media/staging/*/

# Remove old processed files (be careful!)
# Only after confirming they're in library
find /mnt/storage/media/staging/4-ready -type d -mtime +30 -exec rm -rf {} \;
```

### Library Scans

- **Staging libraries**: Usually auto-update with real-time monitoring
- **Final libraries**: May need manual scan if files moved while Jellyfin was stopped

To manually scan:
1. Dashboard → Libraries
2. Click on library name
3. Click **Scan Library**

---

## Troubleshooting

### Files not showing in staging libraries

**Check**:
1. Paths are correct in library settings
2. Media user has read permissions: `ls -la /mnt/storage/media/staging/1-ripped/`
3. Container has access to `/mnt/storage` mount point

**Fix**:
```bash
# On host
chown -R media:media /mnt/storage/media/staging
chmod -R 755 /mnt/storage/media/staging
```

### Jellyfin fetching metadata for staging libraries

**Check**:
- Library type is "Folders" (not Movies or TV Shows)
- All metadata downloaders are disabled in library settings

**Fix**:
- Edit library → Metadata Options → Uncheck all downloaders

### Can't play files in staging libraries

**Check**:
- File permissions: `ls -la /path/to/file.mkv`
- File is not corrupted: Try playing with VLC first
- Jellyfin has required codecs

---

## Security Note

The 4 staging libraries are read-only in practice:
- You never modify files through Jellyfin
- All changes done via scripts on command line
- Jellyfin just provides convenient viewing interface

If you want to prevent accidental deletions:
- Don't give users permission to delete from staging libraries
- Keep staging libraries visible only to admin account

---

**Status**: Ready to implement  
**Time to setup**: 15-20 minutes  
**Next**: See directory-migration-plan.md for directory setup
