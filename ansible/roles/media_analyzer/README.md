# Ansible Role: media_analyzer

Configures a container with media analysis and remuxing tools for the homelab media pipeline.

## Description

This role installs and configures tools for analyzing, organizing, and remuxing media files:
- **mkvtoolnix** - MKV remuxing and manipulation
- **mediainfo** - Media file analysis
- **jq, bc** - Script utilities for JSON processing and calculations
- **FileBot** (optional) - Automated media organization

The role also deploys media pipeline scripts for:
- Analyzing media files (duration, size, tracks)
- Detecting duplicate files
- Organizing and remuxing movies and TV shows
- Promoting files through pipeline stages
- FileBot integration for library organization

## Requirements

- Debian 12 (Bookworm) or compatible OS
- Media user created (handled by `common` role)
- Storage mount at `/mnt/staging` or configured path

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

```yaml
# Install FileBot (optional, requires Java)
media_analyzer_install_filebot: false

# FileBot version (if installing)
filebot_version: "5.1.3"

# Packages to install (can be extended)
media_analyzer_packages:
  - mkvtoolnix
  - mediainfo
  - jq
  - bc
  - rsync
  - curl
  - wget
  - nano
  - tree

# Staging base path (where media pipeline is mounted)
staging_base_path: "/mnt/staging"
```

## Dependencies

None. However, typically used with:
- `common` role (creates media user, system setup)

## Example Playbook

```yaml
- hosts: analyzer_containers
  become: yes
  
  vars:
    media_analyzer_install_filebot: true  # Enable FileBot installation
  
  roles:
    - role: common
    - role: media_analyzer
```

## Scripts Deployed

The role deploys the following scripts to `/home/media/scripts/`:

1. **analyze-media.sh** - Analyze MKV files
   - Shows duration, size, resolution, track counts
   - Detects potential duplicates
   - Categorizes files (main features vs extras)

2. **organize-and-remux-movie.sh** - Process movies
   - Analyzes and categorizes files
   - Remuxes to remove non-English/Bulgarian tracks
   - Organizes to `2-remuxed/movies/` with extras subfolder

3. **organize-and-remux-tv.sh** - Process TV shows
   - Similar to movie script but for TV series
   - Organizes by season and episode

4. **promote-to-ready.sh** - Move files through pipeline
   - Promotes from `3-transcoded/` to `4-ready/`
   - Prepares for final library import

5. **filebot-process.sh** - FileBot automation
   - Automated media organization
   - Moves from staging to final library

6. **fix-current-names.sh** - Fix naming issues
   - Utility for correcting file names

## Container Integration

This role is designed for LXC containers with:
- **Privileged mode** - For storage access consistency
- **Storage mount** - `/mnt/storage/media/staging` → `/mnt/staging`
- **Resources** - 2 cores, 4GB RAM recommended

## Usage After Deployment

```bash
# Enter container
pct enter 303  # or appropriate CTID

# Switch to media user
su - media

# Analyze ripped media
~/scripts/analyze-media.sh /mnt/staging/1-ripped/movies/Movie_Name/

# Organize and remux a movie
~/scripts/organize-and-remux-movie.sh /mnt/staging/1-ripped/movies/Movie_Name/

# Organize and remux TV shows
~/scripts/organize-and-remux-tv.sh "Show Name" 01

# Promote to ready stage
~/scripts/promote-to-ready.sh /mnt/staging/3-transcoded/movies/Movie_Name/

# Process with FileBot (if installed)
~/scripts/filebot-process.sh /mnt/staging/4-ready/movies/Movie_Name/
```

## Verification

After running this role, verify:

```bash
# Check tool versions
mkvmerge --version
mediainfo --version
jq --version
filebot --version  # if enabled

# Check scripts are deployed
ls -la /home/media/scripts/

# Check staging mount
ls -la /mnt/staging/

# Test a script
su - media -c "~/scripts/analyze-media.sh --help"
```

## License

MIT

## Author Information

Created for homelab media pipeline automation.
