# Disk Upgrade & Recovery Simulation Plan

**Status**: Idea / Planning  
**Created**: 2025-11-13  
**Purpose**: Combine disk upgrade with SnapRAID recovery simulation to gain confidence in disaster recovery procedures

---

## Overview

This plan outlines how to safely upgrade a 10TB disk to 18TB while simultaneously testing SnapRAID recovery procedures. This serves dual purposes:
1. **Practical upgrade**: Gain additional storage capacity
2. **DR testing**: Validate recovery procedures in a controlled scenario before you actually need them in a crisis

---

## Current State

### Storage Configuration

| Disk | Device | Model | Capacity | Used | Role |
|------|--------|-------|----------|------|------|
| disk1 | sdc | WD Red Plus 10TB | 9.1TB | 3.7TB (43%) | Data |
| disk2 | sdd | Seagate Barracuda 10TB | 9.1TB | 166GB (2%) | Data |
| disk3 | sdb | WD Red Plus 18TB | 16.4TB | 648GB (5%) | Data |
| parity | sda | WD Red Plus 18TB | 16.4TB | 3.8TB (25%) | Parity |

**Total Capacity**: 35TB data + 16.4TB parity  
**MergerFS Policy**: `eppfrd` (existing path, percentage free space with random distribution)

### Why disk2 is Perfect for Testing

- **Minimal data**: Only 166GB to migrate (vs 3.7TB on disk1)
- **Consumer grade**: Seagate Barracuda (less reliable than WD Red)
- **Low risk**: Least used disk
- **Real scenario**: Simulates actual disk failure and replacement

---

## Prerequisites

### Before You Order the New Disk

1. **Verify current SnapRAID state**
   ```bash
   ssh root@homelab "snapraid status"
   ```
   - Check for any existing errors
   - Note the last sync/scrub dates

2. **Run a full SnapRAID sync**
   ```bash
   ssh root@homelab "snapraid sync"
   ```
   - Ensures parity is up-to-date
   - Critical for recovery testing

3. **Run SnapRAID scrub** (verify parity integrity)
   ```bash
   ssh root@homelab "snapraid scrub -p 100"
   ```
   - Verifies 100% of parity data
   - Takes several hours
   - Ensures parity can actually recover data

4. **Verify backups are current**
   - Check CT300 (backup container) status
   - Ensure recent Restic snapshots exist
   - Confirm Backblaze B2 connection working

5. **Document current setup**
   ```bash
   ssh root@homelab "cat /etc/snapraid.conf" > ~/snapraid-backup.conf
   ssh root@homelab "cat /etc/fstab | grep mnt/disk" > ~/fstab-backup.txt
   ssh root@homelab "lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL" > ~/lsblk-backup.txt
   ```

### Purchase Decision

**Recommended**: Start with **one 18TB drive** to replace disk2

**Why?**
- Lowest risk (minimal data to move)
- Immediate 9TB capacity gain (35TB → 44TB)
- Current usage: 4.5TB / 35TB = 13% full
- 44TB gives you years of headroom
- Can upgrade disk1 later if needed

**Where to buy**: Check [/r/DataHoarder](https://reddit.com/r/datahoarder) for current best deals
- Look for WD Red Plus or Seagate IronWolf (NAS-rated)
- Avoid WD Red SMR drives (get CMR/PMR only)
- Consider shucking WD EasyStore/Elements external drives for savings

---

## Phase 1: New Drive Burn-In (Week 1)

**Purpose**: Stress test the new drive before trusting it with data

### Why Burn-In?

From Perfect Media Server:
> "It is much better to have the drive fail within the first 14 days during which time I don't have to go through a manufacturer RMA or worse, lose data and have to go through a PITA RMA. Weed out the weaklings early."

**Failure rate**: ~2 out of every 20-25 drives fail during burn-in testing!

### Setup

1. **Physical installation**
   - Power down Proxmox host
   - Install new 18TB drive (temporarily as additional disk)
   - Power on and identify new disk
   ```bash
   ssh root@homelab "lsblk -o NAME,SIZE,MODEL,SERIAL"
   ```

2. **Download burn-in script**
   ```bash
   ssh root@homelab
   cd /root
   git clone https://github.com/Spearfoot/disk-burnin-and-testing.git
   cd disk-burnin-and-testing
   ```

3. **Prepare for destructive testing**
   - Read the script README carefully
   - Modify script to enable destructive writes (non-zero value)
   - **CRITICAL**: Verify you're targeting the correct device!

### Run Burn-In Test

```bash
# Start a tmux session (so you can disconnect)
tmux new -s burnin

# Identify the new disk (example: /dev/sde)
lsblk

# Run burn-in script (DESTRUCTIVE - will erase all data!)
# WARNING: TRIPLE CHECK THE DEVICE NAME!
./disk-burnin.sh /dev/sde

# Monitor temperature in another pane
# Ctrl-B then " to split pane horizontally
watch -n 60 hddtemp /dev/sde

# Detach from tmux: Ctrl-B then D
# Reattach later: tmux a -t burnin
```

### What to Expect

- **Duration**: 5-7 days for an 18TB drive
- **Process**:
  1. SMART short test
  2. SMART long test
  3. `badblocks` - 4 complete write/read cycles
  4. Final SMART test
- **Temperature**: Monitor with `hddtemp` (should stay under 50°C)

### Pass/Fail Criteria

**PASS** if:
- All SMART tests complete successfully
- No bad blocks found
- No SMART errors reported
- Drive temperature stays reasonable (<50°C)

**FAIL** if:
- Any bad blocks detected → RMA immediately
- SMART errors appear → RMA immediately  
- Drive dies during test → RMA immediately (this happens!)

**If FAIL**: Return/RMA the drive. Do NOT proceed with using it!

---

## Phase 2: Recovery Simulation (Day 7-8)

**Assumption**: New drive passed burn-in tests

### Goal
Simulate disk2 failure and practice SnapRAID recovery procedures

### Step 1: Pre-Recovery Preparation

1. **Final SnapRAID sync**
   ```bash
   ssh root@homelab "snapraid sync"
   ```

2. **Verify parity is current**
   ```bash
   ssh root@homelab "snapraid status"
   ```
   - Should show 0 files to sync

3. **Document disk2 contents** (for verification later)
   ```bash
   ssh root@homelab "find /mnt/disk2 -type f | tee /root/disk2-file-list.txt"
   ssh root@homelab "du -sh /mnt/disk2/*"
   ```

4. **Stop all containers accessing storage**
   ```bash
   ssh root@homelab "pct stop 301"  # Samba
   ssh root@homelab "pct stop 302"  # Ripper
   ssh root@homelab "pct stop 303"  # Analyzer
   ssh root@homelab "pct stop 304"  # Transcoder
   ssh root@homelab "pct stop 305"  # Jellyfin
   ```

### Step 2: Simulate Disk Failure

**Option A: Physical removal (recommended for realism)**
```bash
# Shutdown host
ssh root@homelab "shutdown -h now"

# Physically unplug disk2 (sdd - Seagate 10TB)

# Boot host back up

# Verify disk is gone
ssh root@homelab "lsblk"
# disk2 should NOT appear
```

**Option B: Unmount (safer, but less realistic)**
```bash
ssh root@homelab
umount /mnt/disk2

# Comment out in fstab to prevent auto-mount
nano /etc/fstab
# Add # before the disk2 line
```

### Step 3: Observe Failure Behavior

1. **Check MergerFS status**
   ```bash
   ssh root@homelab "df -h /mnt/storage"
   ssh root@homelab "ls -la /mnt/storage"
   ```
   - Storage pool should still be accessible
   - Capacity reduced by 9.1TB

2. **Attempt to access disk2 files**
   ```bash
   # Try to read a file that was on disk2
   # This SHOULD FAIL (file not accessible)
   ```

3. **Check SnapRAID status**
   ```bash
   ssh root@homelab "snapraid status"
   ```
   - Should report disk2 as missing or with errors

**Learning moment**: This is what a real disk failure looks like!

---

## Phase 3: Recovery & Upgrade (Day 8)

### Step 1: Prepare New Disk

1. **Partition the new 18TB drive**
   ```bash
   ssh root@homelab

   # Identify new drive (should be /dev/sde or similar)
   lsblk

   # Create partition table
   parted /dev/sde
   (parted) mklabel gpt
   (parted) mkpart primary ext4 0% 100%
   (parted) quit

   # Format with ext4
   mkfs.ext4 -L disk2-new /dev/sde1
   ```

2. **Update /etc/fstab**
   ```bash
   # Get new disk UUID
   blkid /dev/sde1

   # Edit fstab
   nano /etc/fstab

   # Replace old disk2 entry with new UUID:
   UUID=<new-uuid> /mnt/disk2 ext4 defaults 0 0
   ```

3. **Mount new disk**
   ```bash
   mount /mnt/disk2
   df -h | grep disk2
   # Should show 18TB capacity
   ```

### Step 2: SnapRAID Recovery

**THIS IS THE CRITICAL TEST!**

```bash
# Tell SnapRAID to fix disk2 using parity
snapraid fix -d d2

# This will:
# 1. Read parity data from /mnt/parity
# 2. Reconstruct files from other data disks + parity
# 3. Write recovered files to /mnt/disk2 (new 18TB)
```

**Expected duration**: Several hours (depends on how much data was on disk2)

**What to watch for**:
- Progress messages showing files being recovered
- No errors reported
- All files successfully reconstructed

### Step 3: Verify Recovery

1. **Compare file lists**
   ```bash
   # Generate new file list
   find /mnt/disk2 -type f > /root/disk2-recovered-list.txt

   # Compare with original
   diff /root/disk2-file-list.txt /root/disk2-recovered-list.txt
   # Should be identical!
   ```

2. **Verify file integrity**
   ```bash
   # Run SnapRAID scrub on just disk2
   snapraid scrub -d d2 -p 100
   ```
   - Should report 0 errors
   - If errors found, recovery failed!

3. **Spot check files manually**
   ```bash
   # Try playing a video file that was on disk2
   # Try opening other files
   ```

### Step 4: Update SnapRAID Config

```bash
nano /etc/snapraid.conf

# No changes needed to disk paths, but verify:
data d2 /mnt/disk2

# Run full sync to update parity
snapraid sync
```

### Step 5: Restart Services

```bash
# Bring containers back online
pct start 301  # Samba
pct start 302  # Ripper
pct start 303  # Analyzer
pct start 304  # Transcoder
pct start 305  # Jellyfin

# Verify MergerFS shows full capacity
df -h /mnt/storage
# Should now show 44TB total (18TB + 9.1TB + 18TB)
```

---

## Phase 4: Post-Recovery Validation (Day 9-10)

### Final Verification Steps

1. **Run full SnapRAID scrub**
   ```bash
   snapraid scrub -p 100
   ```
   - Verifies entire array integrity
   - Should report 0 errors

2. **Test normal operations**
   - Copy files to /mnt/storage
   - Verify they appear in containers
   - Watch where new files land (should favor disk2 now - most free space)

3. **Monitor for 48 hours**
   - Check SMART status daily
   ```bash
   smartctl -a /dev/sde
   ```
   - Watch for any errors or warnings
   - Monitor temperatures

4. **Update documentation**
   - Update `docs/reference/current-state.md` with new disk2 specs
   - Update `notes/wip/SYSTEM-SNAPSHOT.md` with current state
   - Document lessons learned

---

## Success Criteria

**Recovery simulation is SUCCESSFUL if:**

- ✅ New drive passed burn-in tests (no bad blocks, SMART errors)
- ✅ SnapRAID `fix` command completed without errors
- ✅ All files recovered match original file list
- ✅ Scrub reports 0 errors after recovery
- ✅ Spot-checked files are intact and playable
- ✅ MergerFS shows correct capacity (44TB)
- ✅ Containers can access storage normally
- ✅ New files write to disk2 (most free space)

**You now have confidence that:**
- SnapRAID recovery procedures work
- Your parity data is valid
- You can handle a real disk failure
- The new drive is reliable (passed burn-in)

---

## Troubleshooting Scenarios

### Burn-In Failures

**Bad blocks detected**:
- STOP immediately
- Do NOT use this drive
- RMA/return to manufacturer
- Order replacement

**Drive dies during burn-in**:
- This is WHY we burn-in! Better now than with data on it.
- RMA/return
- Start over with replacement

### Recovery Failures

**SnapRAID fix reports errors**:
```bash
# Check which files failed
snapraid status

# Possible causes:
# 1. Parity was out of sync (should have run sync first!)
# 2. Multiple disk failures (parity can only recover ONE disk)
# 3. Parity corruption (rare but possible)

# If only a few files affected:
# - Restore from backups (CT300 - Restic)
# - Re-rip if media files
```

**Files recovered but corrupted**:
- Check if you ran `snapraid sync` before simulating failure
- Verify with `snapraid status` - should show 0 files to sync
- If parity was stale, recovery will restore OLD data, not current

**Recovery takes too long**:
- Normal! Recovery reads from parity + all other disks
- Expect ~50-100 MB/s recovery speed
- 166GB should take ~30-60 minutes
- Larger recoveries (3.7TB) would take 10+ hours

### MergerFS Issues

**Files missing after recovery**:
```bash
# Check if MergerFS sees the disk
ls /mnt/disk*

# Verify mount points
df -h | grep disk

# Restart MergerFS
umount /mnt/storage
mount /mnt/storage
```

---

## Future Disk1 Upgrade (Optional)

**When**: Only if you need >44TB capacity

**Process**: Same as disk2, but:
- More data to migrate (3.7TB)
- Longer recovery time (10+ hours)
- Good opportunity to rebalance data across all disks

**Temporary data placement**:
```bash
# Before removing disk1, temporarily move data to disk2/disk3
# disk2 new: 18TB with only 166GB used = 17.8TB free
# disk3: 18TB with 648GB used = 17.3TB free
# Total temporary space: 35TB+ available

# After disk1 upgrade to 18TB:
# Final config: 18TB + 18TB + 18TB = 54TB total
```

---

## Cost Analysis

### Single Disk Upgrade (disk2)

**Purchase**:
- 1x 18TB drive: ~$250-300 USD

**Result**:
- Capacity: 35TB → 44TB (+9TB)
- Cost per TB: ~$28-33/TB for new space
- **Recommendation**: Do this first

### Dual Disk Upgrade (disk2 + disk1)

**Purchase**:
- 2x 18TB drives: ~$500-600 USD

**Result**:
- Capacity: 35TB → 54TB (+19TB)
- Cost per TB: ~$26-32/TB for new space
- All disks matched (easier management)

---

## Timeline Summary

| Day | Phase | Tasks | Duration |
|-----|-------|-------|----------|
| 0 | Prep | Order disk, verify backups, sync SnapRAID | 2-4 hours |
| 1-7 | Burn-in | Install disk, run burn-in script | 5-7 days |
| 7 | Simulation | Stop services, "fail" disk2, observe behavior | 1 hour |
| 8 | Recovery | Format new disk, run SnapRAID fix, verify | 4-6 hours |
| 9-10 | Validation | Scrub, monitoring, documentation | 2 hours |

**Total active work**: ~10-15 hours  
**Total calendar time**: ~10 days (mostly waiting for burn-in)

---

## Learning Outcomes

After completing this plan, you will:

1. **Understand SnapRAID recovery** - hands-on experience with `snapraid fix`
2. **Trust your parity** - verified it can actually recover data
3. **Know your limits** - single parity can only recover ONE disk at a time
4. **Have practiced under pressure** - but in a controlled scenario
5. **Gained storage capacity** - 9TB more space (or 19TB if both disks)
6. **Documented the process** - easier next time

---

## Safety Notes

### Data Safety

- ✅ **Low risk**: disk2 only has 166GB (likely staging/temp files)
- ✅ **Backups exist**: CT300 (Restic) has everything important
- ✅ **Can abort**: If recovery fails, restore from backups instead
- ⚠️ **Don't skip burn-in**: 2/25 drives fail during testing!
- ⚠️ **Sync before simulation**: Stale parity = failed recovery

### Physical Safety

- ⚠️ **Drive temperatures**: Monitor during burn-in (<50°C)
- ⚠️ **Power protection**: Ensure UPS is working
- ⚠️ **Anti-static**: Ground yourself when handling drives
- ⚠️ **Backup power supply**: Verify PSU can handle additional drive

---

## References

- [Perfect Media Server - New Drive Burn-In](https://perfectmediaserver.com/06-hardware/new-drive-burnin/)
- [SnapRAID Manual](https://www.snapraid.it/manual)
- [Spearfoot Disk Burn-In Scripts](https://github.com/Spearfoot/disk-burnin-and-testing)
- [Backblaze Drive Stats](https://www.backblaze.com/blog/backblaze-drive-stats/)
- [/r/DataHoarder Wiki](https://www.reddit.com/r/DataHoarder/wiki/)

---

## Notes

**Created**: 2025-11-13  
**Status**: Ready to execute when new disk arrives  
**Next Steps**:
1. Order 18TB drive (WD Red Plus or Seagate IronWolf recommended)
2. Run SnapRAID sync + scrub while waiting for delivery
3. Follow Phase 1 when disk arrives

**Questions to resolve**:
- [ ] Which 18TB model to buy? (check /r/DataHoarder for current deals)
- [ ] Run burn-in on Proxmox host or separate machine?
- [ ] Should I live stream the recovery for documentation? 🎥

---

*"In data we trust, but we verify with parity."* - Ancient storage proverb
