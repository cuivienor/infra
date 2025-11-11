# Media Pipeline Scripts

Organized collection of scripts for the homelab media processing pipeline.

---

## Directory Structure

```
scripts/media/
├── production/      # Active, deployed scripts in use
├── utilities/       # Helper/configuration scripts
├── migration/       # One-time migration scripts (deprecated)
└── archive/         # Old prototypes/superseded scripts
```

---

## Production Scripts

These scripts are actively used in the media pipeline workflow.

### Ripping (CT302 - IaC Ripper)

**`production/rip-disc.sh`**
- **Purpose**: Rip Blu-ray/DVD discs with MakeMKV
- **Container**: CT302 (ripper) @ 192.168.1.70
- **Output**: `/mnt/staging/1-ripped/[movies|tv]/`
- **Usage**:
  ```bash
  # Movie
  ./rip-disc.sh movie "Movie Name"
  
  # TV Show
  ./rip-disc.sh show "Show Name" "S01 Disc1"
  ```
- **Features**:
  - Auto-detects mount point (`/mnt/staging` in CT302, `/mnt/storage/media/staging` elsewhere)
  - Adds date stamps to folders
  - Renames TV episodes with disc identifiers

### Analysis (CT202 - Analyzer)

**`production/analyze-media.sh`**
- **Purpose**: Analyze MKV files and detect duplicates
- **Container**: CT202 (analyzer) @ 192.168.1.72
- **Usage**:
  ```bash
  ./analyze-media.sh "/mnt/storage/media/staging/1-ripped/movies/Movie_Name_2025-11-11/"
  ```
- **Features**:
  - Shows file metadata (duration, size, audio/subtitle tracks)
  - Identifies potential duplicates
  - Helps determine main feature vs extras

### Organization & Remuxing (CT201 - Transcoder)

**`production/organize-and-remux-movie.sh`**
- **Purpose**: Process movies from 1-ripped to 2-remuxed
- **Container**: CT201 (transcoder-new) @ 192.168.1.77
- **Input**: `/mnt/storage/media/staging/1-ripped/movies/Movie_Name_2025-11-11/`
- **Output**: `/mnt/storage/media/staging/2-remuxed/movies/Movie_Name/`
- **Usage**:
  ```bash
  ./organize-and-remux-movie.sh "/path/to/1-ripped/movies/Movie_Name_2025-11-11/"
  ```
- **Features**:
  - Categorizes main features vs extras (by duration/size)
  - Remuxes to keep only English/Bulgarian tracks
  - Creates `extras/` subfolder

**`production/organize-and-remux-tv.sh`**
- **Purpose**: Process TV shows from 1-ripped to 2-remuxed
- **Container**: CT201 (transcoder-new) @ 192.168.1.77
- **Input**: `/mnt/storage/media/staging/1-ripped/tv/Show_Name/`
- **Output**: `/mnt/storage/media/staging/2-remuxed/tv/Show_Name/Season_##/`
- **Usage**:
  ```bash
  ./organize-and-remux-tv.sh "Show Name" 01
  ```
- **Features**:
  - Finds all discs for specified season
  - Interactive extra identification
  - Auto-numbers episodes
  - Remuxes with track filtering (eng/bul only)

### Transcoding (CT201 - Transcoder)

**`production/transcode-queue.sh`**
- **Purpose**: Batch transcode to archival quality x265
- **Container**: CT201 (transcoder-new) @ 192.168.1.77
- **Input**: `/mnt/storage/media/staging/2-remuxed/`
- **Output**: `/mnt/storage/media/staging/3-transcoded/` (mirrors structure)
- **Usage**:
  ```bash
  # Software encoding (default)
  ./transcode-queue.sh "/path/to/2-remuxed/movies/" 20 software
  
  # Hardware encoding (Intel Arc GPU)
  ./transcode-queue.sh "/path/to/2-remuxed/movies/" 20 hardware
  
  # Auto mode (no confirmation, for nohup)
  nohup ./transcode-queue.sh "/path/to/2-remuxed/movies/" 20 software --auto &
  ```
- **Features**:
  - Queue-based processing
  - CRF quality control (18-22)
  - Hardware acceleration support
  - Progress tracking
  - Automatic resume on restart

### Promotion (CT201 - Transcoder)

**`production/promote-to-ready.sh`**
- **Purpose**: Promote verified transcodes from 3-transcoded to 4-ready
- **Container**: CT201 (transcoder-new) @ 192.168.1.77
- **Input**: `/mnt/storage/media/staging/3-transcoded/`
- **Output**: `/mnt/storage/media/staging/4-ready/`
- **Usage**:
  ```bash
  ./promote-to-ready.sh "/path/to/3-transcoded/movies/Movie_Name_2025-11-11/"
  ```
- **Features**:
  - Removes date stamps from folder names
  - Copies files (safe, doesn't delete source automatically)
  - Confirmation before source deletion

**`production/filebot-process.sh`**
- **Purpose**: Process media with FileBot (final naming and organization)
- **Container**: CT201 (transcoder-new) @ 192.168.1.77
- **Input**: `/mnt/storage/media/staging/4-ready/`
- **Output**: `/mnt/storage/media/[movies|tv]/`
- **Usage**:
  ```bash
  ./filebot-process.sh "/path/to/4-ready/movies/Movie_Name/"
  ```
- **Features**:
  - Auto-detects type (movie or TV)
  - Dry-run preview before execution
  - Moves files to final library with proper naming

---

## Utilities

Helper and configuration scripts for one-time or occasional use.

**`utilities/configure-makemkv.sh`**
- **Purpose**: Configure MakeMKV settings for media user
- **Container**: CT302 (ripper) or CT200 (ripper-new)
- **Usage**: Run on ripper container as media user
- **Note**: Mostly superseded by Ansible automation

**`utilities/fix-current-names.sh`**
- **Purpose**: Add disc identifiers to files already in 1-ripped (fix duplicate names)
- **Container**: Any with access to staging
- **Usage**: One-time fix for Jellyfin scanning issues
- **Status**: Used once, may be needed again if issues recur

---

## Migration Scripts (Deprecated)

These scripts were used for one-time directory structure migrations and are now deprecated.

**`migration/migrate-staging.sh`**
- **Purpose**: Migrate existing files to new 4-stage structure
- **Status**: ✅ Completed - No longer needed
- **Note**: Kept for historical reference

**`migration/migrate-to-1-ripped.sh`**
- **Purpose**: Move all existing files to 1-ripped for workflow testing
- **Status**: ✅ Completed - No longer needed
- **Note**: Kept for historical reference

---

## Archived Scripts

Old prototypes and superseded scripts kept for reference.

**`archive/organize-media.sh`**
- **Purpose**: Early interactive organize/multiplex workflow
- **Status**: Superseded by `organize-and-remux-*.sh` scripts
- **Note**: Original prototype, replaced by type-specific scripts

**`archive/transcode-media.sh`**
- **Purpose**: Single-file transcoding script
- **Status**: Superseded by `transcode-queue.sh`
- **Note**: Early prototype, replaced by queue-based batch system

---

## Media Pipeline Workflow

### Complete Workflow Overview

```
1. RIP (CT302)
   └─> rip-disc.sh → 1-ripped/

2. ANALYZE (CT202)  
   └─> analyze-media.sh (identify main features vs extras)

3. ORGANIZE & REMUX (CT201)
   ├─> organize-and-remux-movie.sh → 2-remuxed/movies/
   └─> organize-and-remux-tv.sh → 2-remuxed/tv/

4. TRANSCODE (CT201)
   └─> transcode-queue.sh → 3-transcoded/

5. PROMOTE (CT201)
   └─> promote-to-ready.sh → 4-ready/

6. FINALIZE (CT201)
   └─> filebot-process.sh → /media/[movies|tv]/

7. SERVE
   └─> Jellyfin (CT101) scans /media/
```

### Container Roles

| Container | IP | Purpose | Scripts |
|-----------|-------|---------|---------|
| **CT302** | 192.168.1.70 | Ripper (IaC) | rip-disc.sh |
| **CT200** | 192.168.1.75 | Ripper (backup) | rip-disc.sh |
| **CT201** | 192.168.1.77 | Transcoder | organize-and-remux-*, transcode-queue, promote-to-ready, filebot-process |
| **CT202** | 192.168.1.72 | Analyzer | analyze-media.sh |
| **CT101** | 192.168.1.128 | Media Server | (Jellyfin - no scripts) |

---

## Quick Reference

### Movie Workflow

```bash
# 1. Rip (CT302)
./production/rip-disc.sh movie "Movie Name"

# 2. Analyze (CT202)
./production/analyze-media.sh "/mnt/storage/media/staging/1-ripped/movies/Movie_Name_2025-11-11/"

# 3. Organize & Remux (CT201)
./production/organize-and-remux-movie.sh "/mnt/storage/media/staging/1-ripped/movies/Movie_Name_2025-11-11/"

# 4. Transcode (CT201)
nohup ./production/transcode-queue.sh "/mnt/storage/media/staging/2-remuxed/movies/Movie_Name/" 20 hardware --auto &

# 5. Promote (CT201)
./production/promote-to-ready.sh "/mnt/storage/media/staging/3-transcoded/movies/Movie_Name_2025-11-11/"

# 6. Finalize (CT201)
./production/filebot-process.sh "/mnt/storage/media/staging/4-ready/movies/Movie_Name/"
```

### TV Show Workflow

```bash
# 1. Rip all discs (CT302)
./production/rip-disc.sh show "Show Name" "S01 Disc1"
./production/rip-disc.sh show "Show Name" "S01 Disc2"

# 2. Organize & Remux (CT201)
./production/organize-and-remux-tv.sh "Show Name" 01

# 3. Transcode (CT201)
nohup ./production/transcode-queue.sh "/mnt/storage/media/staging/2-remuxed/tv/Show_Name/Season_01/" 20 hardware --auto &

# 4. Promote (CT201)
./production/promote-to-ready.sh "/mnt/storage/media/staging/3-transcoded/tv/Show_Name/Season_01_2025-11-11/"

# 5. Finalize (CT201)
./production/filebot-process.sh "/mnt/storage/media/staging/4-ready/tv/Show_Name/"
```

---

## Maintenance

### Adding New Scripts

1. Create script in appropriate directory
2. Make executable: `chmod +x script.sh`
3. Add documentation to this README
4. Update Ansible playbooks if deployed via automation

### Script Organization Rules

- **production/**: Scripts actively used in workflow
- **utilities/**: Helper scripts, occasional use
- **migration/**: One-time migration scripts (mark as deprecated after use)
- **archive/**: Old versions, prototypes, superseded scripts

### Updating Deployed Scripts

Scripts deployed via Ansible (e.g., rip-disc.sh on CT302):

```bash
# Update and re-deploy
cd ~/dev/homelab-notes/ansible
ansible-playbook playbooks/ct302-ripper.yml --vault-password-file ../.vault_pass --tags scripts
```

---

## See Also

- **Media Pipeline v2**: `docs/guides/media-pipeline-v2.md`
- **Quick Reference**: `docs/reference/media-pipeline-quick-reference.md`
- **Container Docs**: `docs/containers/`

---

**Last Updated**: 2025-11-11  
**Status**: Organized and documented
