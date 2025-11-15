# Media Pipeline Scripts

Scripts for the homelab media processing pipeline.

## Directory Structure

```
scripts/media/
├── production/      # Active scripts deployed to containers
└── utilities/       # Helper scripts
```

---

## Production Scripts

Deployed to containers via Ansible.

### `rip-disc.sh`
- **Host**: ripper
- **Purpose**: Rip Blu-ray/DVD discs with MakeMKV
- **Output**: `/mnt/staging/1-ripped/[movies|tv]/`

### `organize-and-remux-movie.sh`
- **Host**: analyzer
- **Purpose**: Organize and remux movies (keep eng/bul tracks)
- **Output**: `/mnt/staging/2-remuxed/movies/`

### `organize-and-remux-tv.sh`
- **Host**: analyzer
- **Purpose**: Organize and remux TV episodes
- **Output**: `/mnt/staging/2-remuxed/tv/`

### `transcode-queue.sh`
- **Host**: transcoder
- **Purpose**: Batch transcode to HEVC (H.265)
- **Output**: `/mnt/staging/3-transcoded/`

### `filebot-process.sh`
- **Host**: analyzer
- **Purpose**: Final naming and organization with FileBot
- **Output**: `/mnt/library/[movies|tv]/`

### `analyze-media.sh`
- **Host**: analyzer
- **Purpose**: Analyze MKV files and detect duplicates
- **Usage**: Manual analysis/debugging

---

## Utilities

### `run-bg.sh`
- **Host**: ripper, analyzer, transcoder
- **Purpose**: Run scripts in background with logging
- **Usage**: `~/scripts/run-bg.sh ~/scripts/rip-disc.sh movie "Title"`
- **Logs**: `~/logs/<script>_<timestamp>.log`

---

## Workflow

```
1. RIP (ripper)       → rip-disc.sh           → 1-ripped/
2. REMUX (analyzer)   → organize-and-remux-*  → 2-remuxed/
3. TRANSCODE (transcoder) → transcode-queue.sh    → 3-transcoded/
4. ORGANIZE (analyzer)    → filebot-process.sh    → library/
5. SERVE (jellyfin)       → Jellyfin
```

---

## Container Deployment

| Hostname | Scripts |
|----------|---------|
| ripper | rip-disc.sh, run-bg.sh |
| analyzer | organize-and-remux-*, filebot-process.sh, analyze-media.sh, run-bg.sh |
| transcoder | transcode-queue.sh, run-bg.sh |

> **Note**: For IP addresses and container IDs, see [Current State](../../docs/reference/current-state.md)

---

## See Also

- [Movie Ripping Workflow](../../docs/guides/ripping-workflow-movie.md)
- [TV Show Ripping Workflow](../../docs/guides/ripping-workflow-tv.md)
- [Media Pipeline Quick Reference](../../docs/reference/media-pipeline-quick-reference.md)

---

**Last Updated**: 2025-11-15
