# Media Pipeline v2 - Current Status

**Date**: 2025-11-10
**Status**: Ready for Testing

## ✅ Completed

### Scripts Created/Updated
- [x] `rip-disc.sh` - Updated with disc identifiers for TV shows
- [x] `migrate-to-1-ripped.sh` - Migration complete
- [x] `fix-current-names.sh` - Fix duplicate filenames in 1-ripped
- [x] `analyze-media.sh` - Save analysis to file
- [x] `organize-and-remux-movie.sh` - Movie processing
- [x] `organize-and-remux-tv.sh` - TV show processing with episode mapping
- [x] `transcode-queue.sh` - New directory structure support
- [x] `promote-to-ready.sh` - Stage promotion
- [x] `filebot-process.sh` - FileBot automation

### Files Migrated
- [x] Dragon - SKIPPED (active transcode)
- [x] Dragon2 → 1-ripped/movies/How_To_Train_Your_Dragon_2_2024-11-10/
- [x] LionKing → 1-ripped/movies/The_Lion_King_2024-11-10/
- [x] Matrix → 1-ripped/movies/The_Matrix_Disc1_2024-11-10/
- [x] Matrix-UHD → 1-ripped/movies/The_Matrix_Disc2_2024-11-10/
- [x] Cosmos → 1-ripped/tv/Cosmos_A_Spacetime_Odyssey/S01_Disc[1-4]_2024-11-10/
- [x] Avatar → 1-ripped/tv/Avatar_The_Last_Airbender/S01_Disc[1-2]_2024-11-10/

## 🎯 Next Steps

### 1. Fix Duplicate Filenames (IMMEDIATE)
```bash
# On CT 201
~/scripts/fix-current-names.sh
```
This adds disc identifiers to Cosmos and Avatar files so Jellyfin doesn't see duplicates.

### 2. Configure Jellyfin Libraries
See: `jellyfin-setup-guide.md`
- Add "Staging - Ripped" library → `/mnt/storage/media/staging/1-ripped`
- Set to "Folders" type, disable all metadata

### 3. Test Movie Workflow (Recommend: Lion King)
```bash
# Analyze
./analyze-media.sh /mnt/storage/media/staging/1-ripped/movies/The_Lion_King_2024-11-10/

# Review in Jellyfin, delete unwanted files

# Organize & Remux
./organize-and-remux-movie.sh /mnt/storage/media/staging/1-ripped/movies/The_Lion_King_2024-11-10/

# Review in Jellyfin "Staging - Remuxed"

# Transcode
./transcode-queue.sh /mnt/storage/media/staging/2-remuxed/movies/The_Lion_King_2024-11-10/ 20 software

# Review in Jellyfin "Staging - Transcoded"

# Promote
./promote-to-ready.sh /mnt/storage/media/staging/3-transcoded/movies/The_Lion_King_2024-11-10/

# FileBot
./filebot-process.sh /mnt/storage/media/staging/4-ready/movies/The_Lion_King/
```

### 4. Test TV Show Workflow (Recommend: Avatar)
```bash
# Analyze each disc
./analyze-media.sh /mnt/storage/media/staging/1-ripped/tv/Avatar_The_Last_Airbender/S01_Disc1_2024-11-10/
./analyze-media.sh /mnt/storage/media/staging/1-ripped/tv/Avatar_The_Last_Airbender/S01_Disc2_2024-11-10/

# Review in Jellyfin, delete unwanted files

# Organize & Remux entire season
./organize-and-remux-tv.sh "Avatar The Last Airbender" 01
# Interactive: mark extras, confirm episode numbering

# Continue with transcode → promote → filebot
```

### 5. Test New Rip (CT 200)
When you rip a new disc:
```bash
./rip-disc.sh show "New Show" "S01 Disc1"
```
Verify disc identifier is automatically added to filenames.

## 📁 Current Structure

```
/mnt/storage/media/staging/
├── 1-ripped/          ← Files here (needs filename fix)
│   ├── movies/
│   │   ├── How_To_Train_Your_Dragon_2_2024-11-10/
│   │   ├── The_Lion_King_2024-11-10/
│   │   ├── The_Matrix_Disc1_2024-11-10/
│   │   └── The_Matrix_Disc2_2024-11-10/
│   └── tv/
│       ├── Cosmos_A_Spacetime_Odyssey/
│       │   ├── S01_Disc1_2024-11-10/
│       │   ├── S01_Disc2_2024-11-10/
│       │   ├── S01_Disc3_2024-11-10/
│       │   └── S01_Disc4_2024-11-10/
│       └── Avatar_The_Last_Airbender/
│           ├── S01_Disc1_2024-11-10/
│           └── S01_Disc2_2024-11-10/
├── 2-remuxed/         ← Empty (ready for processing)
├── 3-transcoded/      ← Empty (ready for processing)
├── 4-ready/           ← Empty (ready for processing)
└── Dragon/            ← Untouched (active transcode)
```

## 🐛 Known Issues

- [ ] **Duplicate filenames in TV shows** - Run fix-current-names.sh to resolve
- [ ] **Dragon folder** - Still in old structure, will move after transcode completes

## 📚 Documentation

- `media-pipeline-v2-implementation.md` - Complete implementation guide
- `media-pipeline-quick-reference.md` - Command cheat sheet
- `jellyfin-setup-guide.md` - Jellyfin configuration
- `directory-migration-plan.md` - Migration details

## 🚀 Ready to Go!

Your pipeline is set up and ready for testing. Start with:
1. `fix-current-names.sh` (fixes Jellyfin duplicate issue)
2. Configure Jellyfin library
3. Test with Lion King (smallest movie)

Good luck! 🎬
