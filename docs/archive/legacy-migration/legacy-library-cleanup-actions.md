# Legacy Library Cleanup - Action Items

**Generated**: November 13, 2025  
**Based on**: Quality analysis of 83 files in `/mnt/storage/media/legacy-media`

## Quick Summary

- ✅ **KEEP**: 66 files (excellent quality for home theater)
- ⚠️ **REVIEW**: 10 files (acceptable but could be better)
- ❌ **DELETE**: 7 files (junk or very poor quality)
- 💾 **Space to reclaim**: ~17GB by deleting junk

---

## Immediate Cleanup (Delete These)

### Junk Files - Delete Now
```bash
# Run these commands on homelab host or analyzer container

# Junk intro files (2 files, ~20MB)
rm "/mnt/storage/media/legacy-media/Movies/1080p/Rain.Man.1988.720p.BluRay.DTS.x264-CyTSuNee/[247]lvpjRnMn1988/place2useupload/Place2Use.net.Intro.mp4"
rm "/mnt/storage/media/legacy-media/Movies/1080p/Rain.Man.1988.720p.BluRay.DTS.x264-CyTSuNee/[247]lvpjRnMn1988/Belangrijk/Place2Use.net.Intro.mp4"

# Corrupt/unreadable file (~450MB)
rm "/mnt/storage/media/legacy-media/old-downloads/Moana.2016.MULTI.1080p.HDLight.H264.AC3-LMPS-TiMnZb.mkv"

# Duplicate low-quality Se7en (~1GB) - you have the 14.50GB excellent version
rm "/mnt/storage/media/legacy-media/Movies/Se7en.1995.REMASTERED.BluRay.720p.H264-20-40/Se7en.1995.REMASTERED.BluRay.720p.H264.mp4"
```

**Space saved**: ~1.5GB

---

## Low Quality - Consider Deleting

These are very low quality. Only keep if you really need them:

### The Sound of Music (1965) - 10.37GB
- **Issue**: Only 576p resolution (DVD quality), 2700 kbps bitrate
- **Recommendation**: Buy 4K Blu-ray and rip properly if you value this film
- **Action**: Delete or archive until you get better version
```bash
# rm -rf "/mnt/storage/media/legacy-media/Movies/The Sound Of Music (1965)/"
```

### The Parent Trap (1998) - 4.01GB
- **Issue**: 720p with low bitrate (4010 kbps)
- **Recommendation**: Buy Blu-ray if you watch this regularly
- **Action**: Delete or archive
```bash
# rm "/mnt/storage/media/legacy-media/Movies/The Parent Trap (1998)/The Parent Trap (1998).mkv"
```

### La folle histoire de l'espace (1987) - 1.45GB
- **Issue**: 720p, 1974 kbps, AAC stereo only
- **Recommendation**: Re-rip from better source
```bash
# rm "/mnt/storage/media/legacy-media/Movies/1080p/espace.1987.BRrip.x264-AAC/La folle histoire de l'espace.1987.BRrip.x264-AAC.1G46.mkv"
```

**Potential space saved**: ~16GB more

---

## Review These (Acceptable but Not Ideal)

### 720p Movies (May Want to Upgrade)

These are mislabeled as 1080p but are actually 720p or less:

**Consider upgrading to 4K when available**:

1. **Edge of Tomorrow** (2014) - 5.46GB, 720p (1280x536)
   - Path: `/mnt/storage/media/legacy-media/Movies/1080p/Edge.Of.Tomorrow.2014.720p.BluRay.x264-SPARKS/`
   - Verdict: Great movie, deserves 4K treatment

2. **Star Wars: The Force Awakens** - 6.56GB, 720p (1280x536)
   - Path: `/mnt/storage/media/legacy-media/Movies/rep-starwarstheforceawakens.720p.bluray.x264.mkv`
   - Verdict: Complete your Star Wars collection in 4K

3. **Guardians of the Galaxy Vol. 2** (2017) - 7.80GB, 720p
   - Path: `/mnt/storage/media/legacy-media/old-downloads/Guardians.of.the.Galaxy.Vol.2.2017.720p.BluRay.DTS.x264-FuzerHD.mkv`
   - Verdict: Visually stunning film, would benefit from 4K

4. **Pirates of the Caribbean: Dead Men Tell No Tales** (2017) - 7.43GB, 720p
   - Verdict: Action film with lots of VFX, 4K would be nice

5. **Rain Man** (1988) - 10.13GB, 720p (1280x692)
   - Verdict: Acceptable for now, low priority for upgrade

6. **Carol** (2015) - 5.46GB, 720p
   - Verdict: Beautiful cinematography, could use upgrade

**TV Shows** (Lower Priority):
- The Princess Diaries (2001) - 870MB, compressed
- Archer S06E06-07 - Animated, acceptable quality
- Moana (2016) DKSub version - 2.04GB, lower bitrate (you have better version)

**Action**: Review individually. Keep for now, replace when you find 4K Blu-rays on sale.

---

## Excellent Quality - Keep These!

### Complete Collections to Keep

**Star Wars Original + Prequel Trilogy** (6 films, ~100GB):
- Episodes I-VI all in excellent quality (9-17GB each)
- DTS 5.1 surround, 8940-14000 kbps
- ✅ Ready for home theater

**Harry Potter Complete Series** (8 films, ~100GB):
- All films including extended editions
- DTS/FLAC 5.1, 9261-11596 kbps
- ✅ Ready for home theater

**Rocky Series** (4 films, ~44GB):
- Rocky I-IV in excellent quality
- 9140-16039 kbps, DTS 5.1
- ✅ Ready for home theater

**Indiana Jones** (2 films, ~18.5GB):
- Raiders of the Lost Ark, Temple of Doom
- 10000 kbps, DTS 5.1
- ✅ Ready for home theater
- 📝 Note: Missing Last Crusade & Crystal Skull

### Top Individual Films (Score 75+)

**Premium Quality** (15000+ kbps bitrate):
- Birdman (2014) - 15.60GB
- Boyhood (2014) - 16.50GB  
- District 9 (2009) - 13.10GB
- Se7en (1995) - 14.50GB
- Memento (2000) - 10.93GB

**Excellent Quality** (10000+ kbps):
- Aliens (1986) Director's Cut - 15.34GB
- Spirited Away (2001) - 10.13GB
- Pulp Fiction (1994) - 12.17GB
- The Usual Suspects (1995) - 8.44GB
- Ghost in the Shell 2: Innocence - 10.47GB

**Very Good Quality** (8000-10000 kbps):
- Ex Machina (2015) - 7.94GB
- The Theory of Everything (2014) - 8.74GB
- The Imitation Game (2014) - 7.65GB
- Blue Ruin (2013) - 6.55GB
- Brooklyn (2015) - 7.64GB
- Dumb and Dumber To (2014) - 7.94GB

**TV Content**:
- Game of Thrones Season 1 (complete, HEVC 1080p)
- Sherlock: The Abominable Bride (5.80GB, 1080p)
- Mr. Robot S01E01-05 (1080p WEB-DL)

**Action**: These are all ready for your home theater. No action needed!

---

## Shopping Wishlist (Optional)

### High Priority 4K Upgrades
Films you have in 720p that would greatly benefit from 4K:

1. **Edge of Tomorrow** - Visually impressive, lots of action
2. **Guardians of the Galaxy Vol. 2** - Colorful VFX showcase
3. **Star Wars: The Force Awakens** - Complete your SW collection in 4K
4. **Pirates of the Caribbean: Dead Men Tell No Tales**

### Collections to Complete

1. **Indiana Jones**:
   - Missing: The Last Crusade (1989)
   - Missing: Kingdom of the Crystal Skull (2008)

2. **Alien Franchise** (you have 1-3):
   - Consider: Alien Resurrection, Prometheus, Alien: Covenant

### Upgrade to 4K (Your Best Films)

If you want the ultimate quality for favorites:
- Star Wars Original Trilogy (4K77, 4K80, 4K83 projects or official 4K)
- Harry Potter 4K Collection
- Rocky 4K Collection
- Interstellar (if you add it)
- Blade Runner 2049 (if you add it)

---

## Summary Commands

### Cleanup Script (Run on homelab or analyzer)

```bash
#!/bin/bash
# Cleanup legacy media junk files

echo "Deleting junk files..."

# Junk intro files
rm "/mnt/storage/media/legacy-media/Movies/1080p/Rain.Man.1988.720p.BluRay.DTS.x264-CyTSuNee/[247]lvpjRnMn1988/place2useupload/Place2Use.net.Intro.mp4"
rm "/mnt/storage/media/legacy-media/Movies/1080p/Rain.Man.1988.720p.BluRay.DTS.x264-CyTSuNee/[247]lvpjRnMn1988/Belangrijk/Place2Use.net.Intro.mp4"

# Corrupt file
rm "/mnt/storage/media/legacy-media/old-downloads/Moana.2016.MULTI.1080p.HDLight.H264.AC3-LMPS-TiMnZb.mkv"

# Duplicate low quality
rm "/mnt/storage/media/legacy-media/Movies/Se7en.1995.REMASTERED.BluRay.720p.H264-20-40/Se7en.1995.REMASTERED.BluRay.720p.H264.mp4"

echo "Cleanup complete! Reclaimed ~1.5GB"
echo ""
echo "Optional: Delete low-quality files to reclaim ~16GB more"
echo "Review the files first before deleting!"
```

Save as `/tmp/cleanup-legacy-junk.sh` and run with `bash /tmp/cleanup-legacy-junk.sh`

---

## Migration Plan

### Phase 1: Immediate (Now)
- ✅ Delete junk files (~1.5GB)
- ✅ Review this assessment
- 📝 Create shopping wishlist for Black Friday / holiday sales

### Phase 2: Short-term (Next 2-3 months)
- 🔄 Move excellent-quality films (66 files) to main library
- 🗑️ Delete low-quality versions (The Sound of Music, etc.) - ~16GB
- 📀 Purchase 4K Blu-rays of favorites during sales
- 🎬 Start re-ripping purchased content

### Phase 3: Long-term (6-12 months)
- 📀 Complete missing collections (Indiana Jones, etc.)
- 🔄 Replace all 720p content with proper 1080p/4K rips
- 🗄️ Archive legacy-media directory
- ✨ Maintain single "gold standard" library in `/mnt/storage/media/library`

---

## Next Actions

1. **Run cleanup script** to delete junk files
2. **Review "MAYBE" files** - decide keep or delete
3. **Create physical media wishlist** for upcoming sales
4. **Start enjoying** your 66 excellent quality films on your home theater!

**Estimated Results**:
- Keep: 567GB of excellent home theater content
- Delete: 17GB of junk/low-quality
- Review: 46.5GB to evaluate
- **Final library**: ~600GB of high-quality content ready for your home theater
