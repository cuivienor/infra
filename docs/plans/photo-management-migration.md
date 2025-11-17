# Photo Management Migration Plan

**Created:** 2025-11-17  
**Status:** Planning  
**Estimated Timeline:** 6-8 weeks  
**Dependencies:** Storage capacity, Immich infrastructure

## Current Situation

### Photo Sources
1. **Google Photos** - Primary storage for recent photos (both partners)
   - Partner sharing enabled
   - Shared albums (owned by others)
   - Years of photos with good metadata (in JSON sidecars)

2. **Old Backups** - Multiple hard drives/locations
   - Unknown quality metadata
   - Potential duplicates across backups
   - May have gaps or inconsistent organization

### Goals
- Self-hosted photo management with Immich
- Preserve all metadata (dates, GPS, faces)
- Maintain couple's shared access to photos
- Clean migration with no gaps or duplicates
- Establish sustainable ongoing workflow

## Architecture Decision

### Chosen Approach: Separate Libraries with Partner Sharing

```
Immich Instance
├── User A (your photos, your uploads)
├── User B (partner's photos, partner's uploads)  
└── Partner Sharing: Bidirectional
    └── "Show in Timeline" = merged view for both
```

**Why this approach:**
- Mirrors Google Photos Partner Sharing behavior
- Clear ownership (who took the photo)
- No duplicate handling during import
- Each person controls their library
- Simple migration process

**Trade-offs:**
- Photos remain in original owner's library (view-only for partner)
- Face recognition is per-user (not shared)
- Duplicates visible if both saved same photo in Google Photos

---

## Phase 0: Prerequisites and Planning

### Hardware Requirements

**Immich Container Specs (LXC or VM):**
- **RAM:** 8-16GB (ML processing is memory intensive)
- **CPU:** 4+ cores dedicated
- **Storage:**
  - Fast SSD/NVMe for PostgreSQL database (10-20GB)
  - Photo storage on existing storage pool
  - ML model cache (~3GB)
- **Optional:** Intel iGPU passthrough for accelerated ML

**Estimated Storage Needs:**
- Current Google Photos library size: _____ GB (both partners)
- Old backups estimated size: _____ GB
- Database overhead: ~2GB per 100K photos
- Thumbnails/previews: ~3GB per 100K photos

### Pre-Migration Checklist

**Google Photos Audit (do this now):**
- [ ] List shared albums you don't own (these won't export!)
- [ ] Save critical photos from others' albums to YOUR library
- [ ] Identify which partner "owns" most of the shared photos
- [ ] Document Google Photos storage usage (Settings → Storage)
- [ ] Note any albums with important metadata/organization

**Old Backups Inventory:**
- [ ] List all backup sources (drives, NAS, cloud)
- [ ] Estimate total size across all sources
- [ ] Identify date ranges covered
- [ ] Note any known metadata issues

**Infrastructure Prep:**
- [ ] Allocate storage pool space for photos
- [ ] Plan Immich container/VM specs
- [ ] Set up reverse proxy (Caddy) for HTTPS access
- [ ] Plan backup strategy for Immich itself

---

## Phase 1: Google Takeout Export (Days 0-7)

### Day 0: Start Exports

**Both partners must do this:**

1. **Go to** [takeout.google.com](https://takeout.google.com)

2. **Configure export:**
   - Click "Deselect all"
   - Select only "Google Photos"
   - Click "Next step"
   - Delivery method: **Download link via email**
   - Frequency: **Export once**
   - File type: **.zip**
   - File size: **50 GB** (larger = fewer files to manage)

3. **Confirm and start export**

4. **Note the start date:** ____________

**Expected timeline:**
- Small library (<50GB): 1-2 days
- Medium library (50-200GB): 3-5 days
- Large library (200GB+): 5-7 days

### While Waiting: Critical Tasks

**Save photos from shared albums you don't own:**
1. Go to Google Photos → Sharing
2. Open each shared album (that someone else created)
3. Select important photos → "Save to your account"
4. These will now be in YOUR Takeout

**Document what won't transfer:**
- Album names/organization (must recreate in Immich)
- Comments on photos
- Shared links (must recreate)
- Google Photos AI features (different ML in Immich)

---

## Phase 2: Immich Infrastructure Setup (Days 1-5)

### Deploy Immich Container

**Option A: Add to Terraform** (Recommended)

Create `terraform/immich.tf`:
```hcl
resource "proxmox_lxc" "immich" {
  target_node  = "homelab"
  hostname     = "immich"
  ostemplate   = "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
  password     = var.container_root_password
  unprivileged = true

  cores  = 4
  memory = 8192  # 8GB, increase for larger libraries
  swap   = 2048

  rootfs {
    storage = "local-zfs"
    size    = "20G"  # OS + Docker + Database
  }

  mountpoint {
    mp      = "/mnt/photos"
    storage = "your-storage-pool"
    size    = "2T"  # Adjust based on library size
    slot    = 0
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "192.168.1.XX/24"  # Assign static IP
    gw     = "192.168.1.1"
  }

  features {
    nesting = true  # Required for Docker
  }
}
```

**Option B: Manual LXC Setup**

```bash
# On Proxmox host
pct create 150 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname immich \
  --cores 4 \
  --memory 8192 \
  --swap 2048 \
  --rootfs local-zfs:20 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.XX/24,gw=192.168.1.1 \
  --features nesting=1 \
  --unprivileged 1

# Add storage mount
pct set 150 -mp0 /mnt/pve/storage-pool/photos,mp=/mnt/photos
```

### Install Docker and Immich

**Inside Immich container:**

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# Create Immich directory
mkdir -p /opt/immich
cd /opt/immich
```

**Create docker-compose.yml:**

```yaml
name: immich

services:
  immich-server:
    container_name: immich_server
    image: ghcr.io/immich-app/immich-server:release
    volumes:
      - ${UPLOAD_LOCATION}:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    env_file:
      - .env
    ports:
      - 2283:2283
    depends_on:
      - redis
      - database
    restart: always
    healthcheck:
      disable: false

  immich-machine-learning:
    container_name: immich_machine_learning
    image: ghcr.io/immich-app/immich-machine-learning:release
    volumes:
      - model-cache:/cache
    env_file:
      - .env
    restart: always
    healthcheck:
      disable: false

  redis:
    container_name: immich_redis
    image: docker.io/redis:6.2-alpine@sha256:84882e87b54734154586e5f8abd4dce69fe7311315e2fc6d67c29614c8de2672
    healthcheck:
      test: redis-cli ping || exit 1
    restart: always

  database:
    container_name: immich_postgres
    image: docker.io/tensorchord/pgvecto-rs:pg14-v0.2.0@sha256:90724186f0a3517cf6914295b5ab410db9ce23190a2d9d0b9dd6463e3fa298f0
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_DB: ${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: '--data-checksums'
    volumes:
      - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
    healthcheck:
      test: pg_isready --dbname='${DB_DATABASE_NAME}' --username='${DB_USERNAME}' || exit 1; Chksum="$$(psql --dbname='${DB_DATABASE_NAME}' --username='${DB_USERNAME}' --tuples-only --no-align --command='SELECT COALESCE(SUM(googlechecksum(googlechecksum(i{row_number(), t})))::bigint, 0) FROM (SELECT * FROM pg_database) t')"; echo "googlechecksum: $$Chksum"
      interval: 5m
      start_interval: 30s
      start_period: 5m
    command: ["postgres", "-c", "shared_preload_libraries=vectors.so", "-c", 'search_path="$$user", public, vectors', "-c", "logging_collector=on", "-c", "max_wal_size=2GB", "-c", "shared_buffers=512MB", "-c", "wal_compression=on"]
    restart: always

volumes:
  model-cache:
```

**Create .env file:**

```bash
# Immich version (use specific version for stability)
IMMICH_VERSION=release

# Database
DB_PASSWORD=<generate-strong-password>
DB_USERNAME=postgres
DB_DATABASE_NAME=immich

# Storage locations
UPLOAD_LOCATION=/mnt/photos/immich
DB_DATA_LOCATION=/opt/immich/postgres

# Optional: Disable telemetry
IMMICH_TELEMETRY_INCLUDE=none
```

**Start Immich:**

```bash
docker compose up -d

# Check status
docker compose ps
docker compose logs -f immich-server
```

### Configure Reverse Proxy

**Add to Caddy** (in your existing proxy container):

```caddyfile
photos.yourDomain.com {
  reverse_proxy immich:2283

  # Handle large uploads
  request_body {
    max_size 50GB
  }
}
```

Or use Tailscale Funnel for external access.

### Initial Immich Configuration

1. **Access web UI:** https://photos.yourDomain.com or http://immich-ip:2283

2. **Create admin account** (first user becomes admin)

3. **Create second user** for partner

4. **Generate API keys** for both users:
   - User Settings → API Keys → New API Key
   - Save these securely (needed for immich-go)

5. **Configure storage:**
   - Admin Settings → Storage Template
   - Recommended: `{{y}}/{{MM}}/{{dd}}/{{filename}}`

6. **Enable partner sharing:**
   - Each user: Account Settings → Partner Sharing
   - Share with the other user
   - Toggle "Show in timeline" for merged view

---

## Phase 3: Cutover Day (Day 7-10)

**This is the critical day when:**
- Google Takeout is ready
- Immich is running and configured
- You switch from Google Photos to Immich for new photos

### Morning: Download Takeouts

```bash
# Download all Takeout archives (both partners)
# Store on fast local storage for processing
mkdir -p /mnt/staging/takeout-you
mkdir -p /mnt/staging/takeout-partner

# Download via browser or wget
# Check email for Google's download links
```

### Afternoon: Switch to Immich

**Critical step - this is your "cutover date":**

1. **Install Immich mobile app** (both partners)
   - iOS: App Store
   - Android: Google Play

2. **Configure auto-upload:**
   - Server URL: https://photos.yourDomain.com
   - Login with your Immich credentials
   - Enable backup
   - Settings:
     - WiFi only (recommended)
     - Include videos: Yes
     - Original quality: Yes
     - Exclude albums: Screenshots (optional)

3. **Disable Google Photos backup:**
   - Google Photos app → Profile → Photos settings
   - Backup → Turn OFF
   - **Do this for both partners**

4. **Note the exact date/time:** ____________
   - Everything before this → from Takeout
   - Everything after this → in Immich already

### Evening: Verify Cutover

- [ ] New photos appearing in Immich
- [ ] Google Photos backup is disabled
- [ ] Partner sharing working
- [ ] Mobile apps uploading correctly

---

## Phase 4: Import Google Photos (Days 8-14)

### Install immich-go

```bash
# On a machine with access to Immich and Takeout files
# Download latest release from:
# https://github.com/simulot/immich-go/releases

wget https://github.com/simulot/immich-go/releases/latest/download/immich-go_Linux_x86_64.tar.gz
tar xzf immich-go_Linux_x86_64.tar.gz
chmod +x immich-go
sudo mv immich-go /usr/local/bin/
```

### Import Your Takeout

```bash
# Set your API key
export IMMICH_API_KEY="your-api-key-here"

# Import with Google Photos mode (handles JSON metadata)
immich-go upload from-google-photos \
  --server=https://photos.yourDomain.com \
  --api-key=$IMMICH_API_KEY \
  --create-albums \
  --auto-archive \
  --keep-untitled-albums \
  --session-tag \
  /mnt/staging/takeout-you/*.zip

# Monitor progress
# This can take hours for large libraries
```

**Important flags:**
- `from-google-photos` - Parses JSON sidecars automatically
- `--create-albums` - Recreates album structure
- `--auto-archive` - Archives duplicates instead of skipping
- `--session-tag` - Tags imports for easy identification

### Import Partner's Takeout

```bash
# Switch to partner's API key
export IMMICH_API_KEY="partner-api-key-here"

immich-go upload from-google-photos \
  --server=https://photos.yourDomain.com \
  --api-key=$IMMICH_API_KEY \
  --create-albums \
  --auto-archive \
  --keep-untitled-albums \
  --session-tag \
  /mnt/staging/takeout-partner/*.zip
```

### Monitor Import Progress

```bash
# Check Immich logs
docker compose logs -f immich-server

# Monitor database size
docker exec immich_postgres psql -U postgres -d immich \
  -c "SELECT count(*) FROM assets;"
```

### Expected Timeline

| Library Size | Import Time | ML Processing |
|--------------|-------------|---------------|
| 10K photos | 1-2 hours | 1-2 days |
| 50K photos | 4-8 hours | 1 week |
| 100K+ photos | 12-24 hours | 2-3 weeks |

---

## Phase 5: Validation (Days 14-21)

### Verify Import Success

**Timeline check:**
- [ ] Oldest photos have correct dates
- [ ] Newest photos (before cutover) have correct dates
- [ ] No gap between Takeout photos and new Immich uploads
- [ ] Timeline scrolls chronologically without jumps

**Metadata verification (spot check 10-20 photos):**
- [ ] Dates correct (especially important events)
- [ ] GPS locations preserved (check map view)
- [ ] Descriptions/captions transferred
- [ ] Albums recreated correctly

**Partner sharing:**
- [ ] Both users can see each other's photos
- [ ] Timeline merging works
- [ ] Search works across both libraries

**Search functionality:**
- [ ] Date search works
- [ ] Location search works
- [ ] Object/scene search works (after ML processing)
- [ ] Face search works (after face clustering)

### Known Issues to Check

1. **Timezone problems:**
   - Google Photos timestamps can be UTC
   - Check photos with known times (screenshots, etc.)

2. **Missing photos:**
   - Compare photo count in Immich vs Google Photos stats
   - Check import logs for errors

3. **Duplicate handling:**
   - Some photos may appear twice if both partners saved them
   - Use Immich's duplicate detection to identify

4. **Album structure:**
   - Shared albums may not fully recreate
   - May need manual organization

### Fix Common Issues

**Wrong dates:**
```bash
# Use ExifTool to fix specific photos
exiftool -DateTimeOriginal="2021:03:15 14:30:22" photo.jpg
```

**Missing from import:**
- Check immich-go logs for errors
- Manually upload via web UI
- Check file permissions

**Faces not grouping:**
- Face recognition takes time (processes in background)
- Admin Settings → Jobs → Check ML processing queue
- Manual merge available in People section

---

## Phase 6: Old Backups Migration (Weeks 3-6)

### Inventory Old Backups

Create a spreadsheet:

| Source | Estimated Size | Date Range | Metadata Quality | Priority |
|--------|---------------|------------|------------------|----------|
| Drive 1 | 50GB | 2010-2015 | Poor (no EXIF) | Medium |
| Drive 2 | 100GB | 2015-2018 | Good (EXIF intact) | High |
| NAS Backup | 200GB | 2008-2020 | Mixed | Low (likely duplicates) |

### Deduplicate Before Import

```bash
# Copy to staging area (NEVER modify originals)
rsync -av /old-backup/ /mnt/staging/old-photos/

# Remove exact duplicates
jdupes -r -d -N /mnt/staging/old-photos/

# Check size reduction
du -sh /mnt/staging/old-photos/
```

### Fix Metadata

**Priority order for date recovery:**

1. **EXIF DateTimeOriginal** (check first)
   ```bash
   exiftool -DateTimeOriginal /mnt/staging/old-photos/ | head -20
   ```

2. **Extract from filenames:**
   ```bash
   # Android pattern: IMG_YYYYMMDD_HHMMSS
   exiftool '-DateTimeOriginal<${filename}' \
     -d "IMG_%Y%m%d_%H%M%S.jpg" -r /mnt/staging/old-photos/

   # iOS pattern: YYYY-MM-DD HH.MM.SS
   exiftool '-DateTimeOriginal<${filename}' \
     -d "%Y-%m-%d %H.%M.%S" -r /mnt/staging/old-photos/
   ```

3. **From folder structure:**
   ```bash
   # If organized as /2015/March/photo.jpg
   exiftool '-DateTimeOriginal<${directory}' \
     -d "%Y/%B" -r /mnt/staging/old-photos/
   ```

4. **Last resort: file modification time**
   ```bash
   # Only if nothing else available
   exiftool '-DateTimeOriginal<FileModifyDate' -r /mnt/staging/old-photos/
   ```

### Import Old Backups

```bash
# Standard upload (not Google Photos mode)
immich-go upload \
  --server=https://photos.yourDomain.com \
  --api-key=$YOUR_API_KEY \
  --recursive \
  --session-tag \
  --ignore-errors \
  /mnt/staging/old-photos/
```

**Import in batches:**
- Start with highest quality/priority source
- Validate each batch before proceeding
- Use session tags to track what came from where

### Handle Duplicates After Import

Immich has built-in duplicate detection:
1. Admin Settings → Jobs → Detect duplicates
2. Review suggestions in UI
3. Merge or delete as appropriate

---

## Phase 7: Ongoing Workflow (Week 6+)

### Daily Workflow

**Automatic:**
- Mobile apps upload new photos to Immich
- ML processing happens in background
- Partner sharing keeps libraries merged

**Manual (as needed):**
- Create albums for events
- Tag important photos
- Review and name faces

### Backup Strategy

**Immich itself needs backup:**

```bash
#!/bin/bash
# /opt/immich/backup.sh

BACKUP_DIR="/mnt/backup/immich/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# 1. Database backup (CRITICAL)
docker exec immich_postgres pg_dumpall -U postgres \
  | gzip > "$BACKUP_DIR/database.sql.gz"

# 2. Config backup
cp /opt/immich/.env "$BACKUP_DIR/"
cp /opt/immich/docker-compose.yml "$BACKUP_DIR/"

# 3. Photos (if not separately backed up)
# Skip if photos are on already-backed-up storage pool

# 4. Verify backup
ls -lh "$BACKUP_DIR"
```

**Add to your Restic backup:**
```bash
# Database dumps
restic backup /mnt/backup/immich/

# Photo storage (large, incremental)
restic backup /mnt/photos/immich/
```

### Maintenance Tasks

**Weekly:**
- [ ] Verify mobile backups working
- [ ] Check Immich container health
- [ ] Review any failed jobs

**Monthly:**
- [ ] Database backup verification
- [ ] Storage usage check
- [ ] Review face recognition accuracy
- [ ] Check for Immich updates

**Quarterly:**
- [ ] Full backup restore test
- [ ] Storage capacity planning
- [ ] Album organization review

### Immich Updates

```bash
# Check for updates
docker compose pull

# Apply update (minor downtime)
docker compose down
docker compose up -d

# Verify after update
docker compose ps
docker compose logs -f
```

**Best practice:** Don't auto-update. Review release notes first.

---

## RAW Photo Workflow (DSLR Users)

### Camera Setup

**Recommended: Shoot RAW+JPEG**
- Set camera to RAW+JPEG Fine (not Basic)
- sRGB color space for JPEG
- Standard/Natural picture profile
- Both files saved with matching names (e.g., `IMG_0001.CR2` + `IMG_0001.JPG`)

**Why RAW+JPEG:**
- JPEG ready immediately (camera does processing)
- RAW available for difficult shots
- No manual processing needed for 95% of photos
- Safety net for exposure/white balance issues

### Immich RAW Handling

**Automatic stacking:**
- Immich detects RAW+JPEG pairs by filename
- Displays as single item in timeline
- Uses embedded JPEG for fast preview
- Both files accessible in asset details
- Settings → Library → "Treat RAW+JPEG as single asset"

**What Immich does:**
- ✅ Displays RAW files
- ✅ Generates thumbnails from RAW
- ✅ Preserves all metadata
- ✅ ML features work on JPEG preview
- ❌ No RAW editing/processing
- ❌ Cannot export processed RAW to JPEG

### Storage Considerations

**RAW file sizes by camera:**

| Camera Type | RAW Size | JPEG Size | Total/Photo |
|------------|----------|-----------|-------------|
| Entry DSLR (24MP) | 20-25 MB | 8-12 MB | ~35 MB |
| Mid-range (32MP) | 35-45 MB | 12-15 MB | ~55 MB |
| Full-frame (33MP+) | 40-60 MB | 15-20 MB | ~70 MB |

**Storage projections:**
- 1000 photos/year (casual): ~35-70 GB/year with RAW+JPEG
- JPEG-only would be: ~10-15 GB/year
- Your 30TB+ free storage: Plenty of room

### Import Workflow

**Simple approach - let Immich handle everything:**

```bash
#!/bin/bash
# /scripts/media/production/import-camera.sh

INCOMING="/mnt/storage/photos/incoming"
IMMICH_LIBRARY="/mnt/storage/photos/immich/library"

# Organize by date and move to Immich library
for file in "$INCOMING"/*.{JPG,CR2,NEF,ARW,RAF,DNG}; do
  [ -f "$file" ] || continue

  # Extract date from EXIF
  date_folder=$(exiftool -DateTimeOriginal -d "%Y/%Y-%m-%d" -s3 "$file")

  if [ -n "$date_folder" ]; then
    mkdir -p "$IMMICH_LIBRARY/$date_folder"
    mv "$file" "$IMMICH_LIBRARY/$date_folder/"
  fi
done

# Trigger Immich library scan
curl -X POST "http://immich:2283/api/library/scan" \
  -H "x-api-key: $IMMICH_API_KEY"
```

**Or simpler - direct to Immich:**
1. Connect camera/SD card
2. Copy all files to Immich upload directory
3. Immich auto-imports and stacks pairs

### When to Process RAW

**Use camera JPEG (95% of time):**
- Good lighting, proper exposure
- Quick sharing/viewing
- No heavy cropping needed
- Colors look fine

**Process RAW when:**
- Exposure significantly wrong (recover highlights/shadows)
- White balance completely off
- Need to crop heavily (more detail in RAW)
- Printing large (maximum quality needed)
- High-contrast scenes (HDR recovery)

**Processing tools (if needed):**
```bash
# darktable-cli (best for Linux)
darktable-cli input.CR2 output.jpg

# rawtherapee-cli
rawtherapee-cli -o output/ -p default.pp3 -c input.NEF

# Simple with dcraw
dcraw -c -w input.NEF | convert - output.jpg
```

### Long-Term Archival Strategy

**Year 1-5: Keep everything**
- Original RAW files (proprietary format)
- Camera JPEGs
- Both backed up via Restic

**Year 5+: Consider DNG conversion**
- Convert proprietary RAW to DNG (Adobe's open format)
- DNG is future-proof (documented, open standard)
- 15-20% smaller than source RAW
- Keep original RAW for another year, then delete

**DNG conversion (batch):**
```bash
# Using Adobe DNG Converter (via Wine or Windows VM)
# Or keep proprietary RAW - your formats (Canon/Nikon/Sony) are well-supported

# Verify metadata preservation
exiftool -TagsFromFile original.NEF -all:all converted.dng
```

**Proprietary format risk assessment:**

| Format | Brand | Risk Level | Support Outlook |
|--------|-------|------------|-----------------|
| .CR2/.CR3 | Canon | Low | Huge user base |
| .NEF | Nikon | Low | Well-documented |
| .ARW | Sony | Low-Medium | Growing support |
| .RAF | Fujifilm | Medium | X-Trans sensor complexity |

### Backup Strategy for RAW Files

**Tiered approach:**

```bash
# Tier 1: All photos (daily backup)
restic backup /mnt/storage/photos/immich/ \
  --tag photos \
  --exclude-caches

# Tier 2: Archive old RAW files separately (monthly)
restic backup /mnt/storage/photos/archive/ \
  --tag raw-archive
```

**Retention policy:**
- JPEGs: 7 daily, 4 weekly, 12 monthly, unlimited yearly
- RAW files: Same (storage is cheap, memories are priceless)

### RAW Workflow Checklist

**After each DSLR session:**
- [ ] Import RAW+JPEG to Immich
- [ ] Verify stacking worked (single timeline entry)
- [ ] Quick scroll through to catch obvious problems
- [ ] Process any RAW files with exposure issues (rare)

**Quarterly:**
- [ ] Review storage usage trend
- [ ] Check RAW file backup status
- [ ] Verify old RAW files still readable

**Yearly:**
- [ ] Assess DNG conversion need for 5+ year old RAW
- [ ] Test RAW file recovery from backup
- [ ] Document camera models used

---

## Rollback Plan

### If Immich Import Fails

**Takeout archives are untouched:**
- Re-run import with different options
- Check logs for specific errors
- Immich can be reset: delete containers, database, start fresh

### If Mobile Upload Fails

**Google Photos still has your photos:**
- Re-enable Google Photos backup temporarily
- Fix Immich issue
- Re-do cutover

### If Immich Becomes Unstable

**Short-term:**
- Restart containers: `docker compose restart`
- Check resource usage (RAM, CPU)
- Review logs for errors

**Long-term:**
- Restore from backup
- Downgrade Immich version if needed
- Your photos remain safe on disk

### Complete Rollback

If Immich doesn't work out:
1. Re-enable Google Photos backup
2. Export from Immich (photos are standard files)
3. Keep Google Photos as primary
4. Try again later with lessons learned

---

## Tools and Resources

### Essential Tools

- **immich-go** - CLI for imports
  - https://github.com/simulot/immich-go

- **ExifTool** - Metadata manipulation
  - `apt install libimage-exiftool-perl`

- **jdupes** - Deduplication
  - `apt install jdupes`

### Immich Resources

- **Official Docs:** https://immich.app/docs
- **GitHub:** https://github.com/immich-app/immich
- **Discord:** Community support
- **Release Notes:** Check before updates

### Useful Commands

```bash
# Check Immich status
docker compose ps

# View logs
docker compose logs -f immich-server

# Database size
docker exec immich_postgres psql -U postgres -d immich \
  -c "SELECT pg_size_pretty(pg_database_size('immich'));"

# Photo count
docker exec immich_postgres psql -U postgres -d immich \
  -c "SELECT count(*) FROM assets;"

# Restart ML processing
docker compose restart immich-machine-learning
```

---

## Timeline Summary

| Week | Phase | Key Activities | Time Required |
|------|-------|----------------|---------------|
| 0 | Planning | Audit, inventory, requirements | 2-3 hours |
| 1 | Google Takeout | Start exports, save shared albums | 1 hour + wait |
| 1-2 | Infrastructure | Deploy Immich, configure | 4-6 hours |
| 2 | Cutover | Enable mobile uploads, disable Google | 1-2 hours |
| 2-3 | Import | Import Google Takeouts | 8-24 hours (mostly unattended) |
| 3-4 | Validation | Verify imports, fix issues | 2-4 hours |
| 4-6 | Old Backups | Dedupe, fix metadata, import | 8-16 hours |
| 6+ | Ongoing | Establish workflow, backups | Ongoing |

**Total hands-on time:** 25-50 hours spread over 6 weeks

---

## Success Criteria

After migration complete:

- [ ] All Google Photos imported with correct metadata
- [ ] Old backups consolidated and deduplicated
- [ ] Mobile auto-upload working for both partners
- [ ] Partner sharing enabled, timeline merged
- [ ] Face recognition trained on key people
- [ ] Backup strategy in place for Immich
- [ ] Google Photos backup disabled (but account kept for safety)
- [ ] No gaps in photo timeline
- [ ] Search functionality working (dates, locations, objects)

---

## Questions to Answer Before Starting

1. **Storage capacity sufficient?**
   - Current Google Photos size × 2 (working space)
   - Plus old backup estimated size
   - Plus 20% growth buffer

2. **Partner onboard with the plan?**
   - Separate libraries OK?
   - Mobile app switch timing?
   - Access requirements?

3. **What's in shared albums you don't own?**
   - List them now
   - Save critical photos to your library
   - Accept some may be lost

4. **Old backups priority?**
   - Worth the effort to recover?
   - Or focus on Google Photos only first?

5. **Immich hardware allocation?**
   - RAM: 8GB or 16GB?
   - Cores: 4 or more?
   - Storage pool ready?

---

## Next Steps

1. **Immediate:** Start Google Takeout (both partners)
2. **This week:** Audit shared albums, save important photos
3. **This week:** Inventory old backup sources
4. **Week 1:** Deploy Immich container
5. **Week 1:** Configure reverse proxy, users, API keys
6. **Week 2:** Cutover day when Takeout ready
7. **Week 2-3:** Import and validate

---

## Related Documents

- `docs/reference/current-state.md` - Infrastructure overview
- `docs/plans/hardware-upgrade-plan.md` - If hardware upgrade needed
- `terraform/` - Infrastructure as code templates
- `ansible/roles/` - Container deployment patterns

---

**Ready to start?** Begin with Google Takeout export (it takes days) and audit shared albums immediately.
