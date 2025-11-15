# MergerFS Storage Rebalancing Guide

**Created**: 2025-11-11  
**Purpose**: Guide for safely rebalancing existing data across MergerFS disks  
**Status**: Reference guide - use when ready to rebalance

---

## Overview

This guide explains how to rebalance existing data across your MergerFS pool. As of 2025-11-11, your storage configuration has been updated to automatically distribute **new** files across all disks using the `eppfrd` policy. This guide is for moving **existing** data when you're ready.

### Current State

```
disk1 (9.1T): 4.1T used (48%) ← IMBALANCED - nearly all existing data
disk2 (9.1T): 470M used (1%)  ← Nearly empty
disk3 (17T):  24G used (1%)   ← Nearly empty
```

### Goal State (Balanced)

```
disk1 (9.1T): ~1.4T used (15%) ← Balanced
disk2 (9.1T): ~1.4T used (15%) ← Balanced
disk3 (17T):  ~1.3T used (8%)  ← Balanced (has more capacity)
```

---

## Important Prerequisites

✅ **Already Completed** (2025-11-11):
- MergerFS policy changed to `eppfrd` (new files auto-distribute)
- Directory structure replicated to disk2 and disk3
- Ownership and permissions set correctly

⚠️ **Before You Start**:
- Ensure SnapRAID sync is current: `ssh homelab "snapraid status"`
- Test with a small directory first
- Have a backup plan if something goes wrong

---

## Strategy Options

### Option A: Gradual Rebalancing (RECOMMENDED)

**Best for**: Production systems that need to stay online

**Pros**:
- ✅ No downtime required
- ✅ Can pause/resume anytime
- ✅ Minimal risk
- ✅ Jellyfin can stay running

**Cons**:
- ⏱️ Takes longer (days/weeks)

**Time Commitment**: 15-30 minutes every few days

---

### Option B: Bulk Rebalancing

**Best for**: Scheduled maintenance windows

**Pros**:
- ✅ Faster (hours instead of days)
- ✅ All done at once

**Cons**:
- ⚠️ Requires stopping services
- ⚠️ Higher risk if interrupted
- ⚠️ Need to monitor throughout

**Time Commitment**: 2-6 hours continuous

---

## Option A: Gradual Rebalancing (Step-by-Step)

### Step 1: Identify What to Move

```bash
# SSH to homelab
ssh homelab

# See what's using space on disk1
du -h --max-depth=2 /mnt/disk1/media | sort -rh | head -20

# Check movies
du -sh /mnt/disk1/media/movies/* | sort -rh | head -20

# Check TV shows
du -sh /mnt/disk1/media/tv/* | sort -rh | head -20

# Check other directories
du -sh /mnt/disk1/*/ | sort -rh
```

### Step 2: Choose Directories to Move

**Best candidates**:
- Complete movie collections (keep related files together)
- Complete TV series (all seasons together)
- Large directories that are self-contained

**Strategy**:
- Move largest items first (biggest impact)
- Keep related content together
- Move to disk2 or disk3 (both are 99% empty)

### Step 3: Move Data Safely with rsync

**Why rsync?**
- Verifies each file after copying
- Can resume if interrupted
- Preserves all metadata (ownership, permissions, timestamps)
- Only deletes source after successful copy

**Template**:
```bash
# Basic format
rsync -avhP --remove-source-files \
  /mnt/disk1/path/to/directory/ \
  /mnt/disk2/path/to/directory/

# Verify the move
ls -la /mnt/disk2/path/to/directory/

# Remove empty source directory
rmdir /mnt/disk1/path/to/directory/
```

**Example: Move a large movie**
```bash
# Move "Guardians of the Galaxy" to disk2
rsync -avhP --remove-source-files \
  /mnt/disk1/Movies/Guardians.of.the.Galaxy.2014.1080p.BluRay.DTS-HD.x264-BARC0DE/ \
  /mnt/disk2/Movies/Guardians.of.the.Galaxy.2014.1080p.BluRay.DTS-HD.x264-BARC0DE/

# Verify
ls -la /mnt/disk2/Movies/Guardians.of.the.Galaxy.2014.1080p.BluRay.DTS-HD.x264-BARC0DE/

# Clean up empty directory
rmdir /mnt/disk1/Movies/Guardians.of.the.Galaxy.2014.1080p.BluRay.DTS-HD.x264-BARC0DE/

# Verify it's accessible through MergerFS
ls -la /mnt/storage/Movies/Guardians.of.the.Galaxy.2014.1080p.BluRay.DTS-HD.x264-BARC0DE/
```

**Example: Move a TV series**
```bash
# Move "Archer (2009)" to disk3 (larger disk, good for TV shows)
rsync -avhP --remove-source-files \
  /mnt/disk1/tv/Archer\ \(2009\)/ \
  /mnt/disk3/tv/Archer\ \(2009\)/

# Verify and clean up
ls -la /mnt/disk3/tv/Archer\ \(2009\)/
rmdir /mnt/disk1/tv/Archer\ \(2009\)/
```

### Step 4: Monitor Progress

Check disk usage after each move:
```bash
df -h /mnt/disk{1,2,3}
```

Target distribution:
- Stop when disk1 reaches ~15-20% usage
- disk2 and disk3 will balance automatically with new files

### Step 5: Run SnapRAID Sync

After moving significant data (every few moves or once per session):
```bash
ssh homelab "snapraid sync"
```

This updates the parity information for your moved files.

---

## Option B: Bulk Rebalancing

⚠️ **Use with caution - requires stopping services**

### Step 1: Stop Services

```bash
# Stop Jellyfin
ssh homelab "pct stop 101"

# Verify no media pipeline scripts are running
ssh homelab "ps aux | grep -E '(makemkv|ffmpeg|filebot)'"
```

### Step 2: Move Large Categories

```bash
# Move all movies to disk2 and disk3
ssh homelab "
  cd /mnt/disk1/Movies
  for dir in */; do
    rsync -avhP --remove-source-files \"\$dir\" /mnt/disk2/Movies/
  done
"

# Move all TV shows to disk3
ssh homelab "
  cd /mnt/disk1/tv
  for dir in */; do
    rsync -avhP --remove-source-files \"\$dir\" /mnt/disk3/tv/
  done
"
```

### Step 3: Verify and Clean Up

```bash
# Check what's left on disk1
ssh homelab "du -sh /mnt/disk1/*"

# Check new distribution
ssh homelab "df -h /mnt/disk{1,2,3}"
```

### Step 4: Sync Parity and Restart

```bash
# Update parity
ssh homelab "snapraid sync"

# Restart Jellyfin
ssh homelab "pct start 101"
```

---

## Monitoring Tools

### Check Disk Balance

Create a quick balance checker:
```bash
#!/bin/bash
# Save as: ~/check-disk-balance.sh

echo "=== Disk Usage ==="
ssh homelab "df -h /mnt/disk{1,2,3} | grep -v Filesystem"

echo ""
echo "=== Per-Disk Breakdown ==="
for disk in disk1 disk2 disk3; do
    echo ""
    echo "📊 /mnt/$disk:"
    ssh homelab "du -sh /mnt/$disk/media/* 2>/dev/null | sort -rh"
done

echo ""
echo "=== Storage by Category ==="
ssh homelab "du -sh /mnt/disk*/Movies /mnt/disk*/media/movies /mnt/disk*/tv /mnt/disk*/media/tv 2>/dev/null | sort -rh"
```

### Track Progress Over Time

```bash
# Save to a log file
date >> ~/storage-balance.log
ssh homelab "df -h /mnt/disk{1,2,3}" >> ~/storage-balance.log
echo "---" >> ~/storage-balance.log
```

---

## Best Practices

### 1. Always Use rsync (Not mv)

❌ **Don't do this**:
```bash
mv /mnt/disk1/Movies/SomeMovie /mnt/disk2/Movies/
```

✅ **Do this**:
```bash
rsync -avhP --remove-source-files /mnt/disk1/Movies/SomeMovie/ /mnt/disk2/Movies/SomeMovie/
```

**Why?** rsync verifies each file before deleting the source.

### 2. Keep Related Files Together

- Move entire movie directories (all files stay together)
- Move entire TV series (all seasons together)
- Don't split a single movie across disks

### 3. Test First

```bash
# Test with a small directory first
rsync -avhP --remove-source-files \
  /mnt/disk1/Movies/TestMovie/ \
  /mnt/disk2/Movies/TestMovie/
```

### 4. Verify Jellyfin Can See Files

After moving, check that Jellyfin still sees the content:
```bash
# Files should still be visible through MergerFS
ls -la /mnt/storage/Movies/MovedMovie/
```

Jellyfin doesn't need to know which physical disk files are on - MergerFS handles that.

### 5. Don't Fill Any Disk Completely

Leave at least 10-15% free space on each disk for:
- File system overhead
- Future SnapRAID operations
- MergerFS `minfreespace` setting (200G)

---

## Troubleshooting

### "No space left on device"

Check available space:
```bash
df -h /mnt/disk2
```

If disk2 is full, switch to disk3:
```bash
rsync -avhP --remove-source-files \
  /mnt/disk1/Movies/Movie/ \
  /mnt/disk3/Movies/Movie/
```

### "Permission denied"

Ensure correct ownership:
```bash
ssh homelab "chown -R media:media /mnt/disk2/Movies /mnt/disk3/Movies"
```

### Files Seem Missing After Move

Check through MergerFS (not individual disks):
```bash
ls -la /mnt/storage/Movies/MovieName/
```

MergerFS will show files from whichever disk they're on.

### Rsync Was Interrupted

Just run the same rsync command again - it will resume from where it stopped:
```bash
rsync -avhP --remove-source-files \
  /mnt/disk1/Movies/Movie/ \
  /mnt/disk2/Movies/Movie/
```

---

## Recommended Rebalancing Schedule

### Week 1-2
- Move 500GB - 1TB total
- Focus on largest movies (10-50GB each)
- 2-3 movies every few days
- Run SnapRAID sync weekly

### Week 3-4
- Move another 500GB - 1TB
- Focus on movie collections or TV series
- Continue gradual approach

### Week 5-6
- Move remaining content
- Balance until disk1 is around 15-20% usage

### After Rebalancing
- New files automatically distribute to emptier disks
- Monitor with `df -h /mnt/disk{1,2,3}`
- No further manual rebalancing needed!

---

## Helper Scripts

### Quick Move Script

Save as `~/quick-move.sh`:
```bash
#!/bin/bash
# Quick move script for gradual rebalancing

if [ $# -ne 3 ]; then
    echo "Usage: $0 <directory> <source-disk> <target-disk>"
    echo "Example: $0 'Movies/SomeMovie' disk1 disk2"
    exit 1
fi

DIR="$1"
SRC="/mnt/$2/$DIR"
TGT="/mnt/$3/$DIR"

echo "Moving: $DIR"
echo "From: $SRC"
echo "To: $TGT"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh homelab "rsync -avhP --remove-source-files '$SRC/' '$TGT/'"
    echo ""
    echo "Verify and remove empty directory:"
    echo "  ssh homelab \"rmdir '$SRC'\""
fi
```

Usage:
```bash
chmod +x ~/quick-move.sh
./quick-move.sh "Movies/Rocky (1976)" disk1 disk2
```

---

## Summary

### What's Already Done (2025-11-11)
✅ MergerFS configured for automatic distribution  
✅ Directory structure replicated across all disks  
✅ New files automatically spread across disk2/disk3

### What This Guide Is For
📖 Moving existing 4.1TB from disk1 to disk2/disk3  
📖 Balancing legacy data when you have time  
📖 Optional - system works fine without it

### Key Takeaways
- Use `rsync -avhP --remove-source-files` for safety
- Move complete directories (keep related files together)
- Gradual approach is safer (15-30 min every few days)
- Run `snapraid sync` after significant moves
- Jellyfin works through MergerFS (doesn't care which disk)

---

**Last Updated**: 2025-11-11  
**Related Docs**:
- `docs/reference/current-state.md` - Storage configuration
- `ansible/roles/proxmox_storage/defaults/main.yml` - MergerFS settings
