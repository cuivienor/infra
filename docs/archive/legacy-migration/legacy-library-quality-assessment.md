# Legacy Library Quality Assessment

**Date**: November 13, 2025  
**Total Files Analyzed**: 83 files  
**Total Size**: 631GB  
**Analysis Tool**: `scripts/media/utilities/analyze-library-quality.sh`

## Executive Summary

Your legacy media library has been analyzed for quality suitable for a home theater setup. The analysis focused on:
- Video codec (H.264/AVC vs HEVC vs older codecs)
- Resolution (4K, 1080p, 720p, <720p)
- Video bitrate (home theater quality requires 8000+ kbps for 1080p)
- Audio quality (DTS/DTS-HD/TrueHD vs AC3 vs compressed AAC/MP3)
- Audio channels (surround sound vs stereo)

## Results Breakdown

### ✅ KEEP (High Quality) - 66 files (~567GB)
**Recommendation**: These files are excellent or good quality for home theater use.

**Top Tier (Score 80+)**:
- **Movies** with excellent bitrate (15000+ kbps):
  - Birdman (2014) - 15.60GB, 17073 kbps
  - Boyhood (2014) - 16.50GB, 12758 kbps
  - Se7en (1995) - 14.50GB, 14868 kbps
  - Indiana Jones (both) - 9GB+ each, 10000 kbps, DTS audio
  - Rocky (1976) - 10.92GB, 11568 kbps
  - Memento (2000) - 10.93GB, 13161 kbps
  - Aliens (1986) Director's Cut - 15.34GB, 12429 kbps

- **Star Wars Collection** - All original trilogy in good quality
  - Episode IV, V, VI - 9-10GB each with DTS surround
  - Episode I, II, III - 15-17GB each

- **Harry Potter Collection** - All films in 1080p with good bitrates
  - Extended editions included
  - 12-14GB per film
  - DTS/AC3 5.1 audio

**TV Shows**:
- Game of Thrones S01 (HEVC 1080p) - Modern codec, space-efficient
- Sherlock: The Abominable Bride (1080p, 8743 kbps)
- Mr. Robot S01E01-05 (1080p WEB-DL)

**Action**: Keep these files. They are good quality for home theater viewing.

---

### ⚠️ MAYBE (Acceptable) - 10 files (~46.5GB)
**Recommendation**: Review case-by-case. May be acceptable depending on content value.

**Issues**: Lower resolution (720p actual, mislabeled as 1080p) or lower bitrates

- Edge of Tomorrow (2014) - 5.46GB, 720p (1280x536), DTS audio
- Rain Man (1988) - 10.13GB, 720p (1280x692), DTS audio
- Carol (2015) - 5.46GB, 720p (1280x688)
- Star Wars: The Force Awakens - 6.56GB, 720p (1280x536)
- Guardians of the Galaxy Vol. 2 (2017) - 7.80GB, 720p
- Pirates of the Caribbean: Dead Men Tell No Tales (2017) - 7.43GB, 720p
- Moana (2016) - One version is 2.04GB, lower bitrate
- The Princess Diaries (2001) - 870MB, compressed audio
- Archer S06E06-07 - Animated, lower priority

**Action**:
- Keep if you value the content and don't plan to purchase physical media
- Good candidates for replacement if you find 4K/Blu-ray versions on sale
- Acceptable quality for casual viewing, but not ideal for home theater

---

### ❌ RE-RIP (Low Quality) - 7 files (~17.3GB)
**Recommendation**: Replace these if you care about the content. Buy Blu-ray and rip properly.

**Critical Issues**: Very low bitrate, poor resolution, or compressed stereo audio

1. **The Sound of Music (1965)** - 10.37GB
   - Issue: 1280x576 (DVD quality), only 2700 kbps bitrate
   - Action: Buy Blu-ray, this deserves better quality

2. **The Parent Trap (1998)** - 4.01GB
   - Issue: 1280x692, only 4010 kbps bitrate
   - Action: Replace if you watch it

3. **La folle histoire de l'espace (1987)** - 1.45GB
   - Issue: 1280x694, 1974 kbps, AAC stereo
   - Action: Very compressed, re-rip recommended

4. **Se7en (1995) REMASTERED** - 1.00GB
   - Issue: 1216x544, only 1107 kbps, AAC stereo
   - Note: You have a MUCH better 14.50GB version! Delete this one.

5. **Moana (2016) HDLight** - 450MB
   - Issue: Cannot even detect properties - corrupt or very poor quality
   - Note: You have better versions, delete this

6. **Place2Use.net.Intro.mp4** (2 copies) - Junk files
   - Action: Delete immediately

**Action**:
- Delete the junk files (Place2Use intros, Se7en duplicate)
- Consider purchasing Blu-rays for The Sound of Music and The Parent Trap if you value them
- Saves ~17GB of space

---

## Detailed Analysis Highlights

### Best Quality Files (Home Theater Ready)
Files with 10000+ kbps bitrate, 1080p resolution, and lossless/DTS audio:

| Title | Size | Bitrate | Audio | Score |
|-------|------|---------|-------|-------|
| Sherlock: Abominable Bride | 5.80GB | 8743 kbps | AC3 5.1 | 85 |
| Spirited Away (2001) | 10.13GB | 10140 kbps | DTS 5.1 | 80 |
| Indiana Jones Raiders | 9.19GB | 10000 kbps | DTS 5.1 | 80 |
| Indiana Jones Temple | 9.39GB | 10000 kbps | DTS 5.1 | 80 |
| Rocky (1976) | 10.92GB | 11568 kbps | DTS 5.1 | 80 |
| Rocky IV (1985) | 10.11GB | 13578 kbps | DTS 5.1 | 80 |
| Aliens (1986) DC | 15.34GB | 12429 kbps | DTS 5.1 | 80 |
| Boyhood (2014) | 16.50GB | 12758 kbps | DTS 5.1 | 80 |
| Birdman (2014) | 15.60GB | 17073 kbps | DTS 5.1 | 80 |

### Space Savings Opportunity
By removing the 7 "RE-RIP" files, you'll save ~17GB and clean up your library.

### Collections Analysis

**Star Wars** (Original + Prequel Trilogies):
- ✅ All 6 films present in good quality
- Bitrate: 8940-14000 kbps
- Size: 9-17GB per film
- Audio: DTS 5.1 surround
- **Verdict**: KEEP all, excellent quality

**Harry Potter** (Complete Series):
- ✅ All 8 films present
- Extended editions where applicable
- Bitrate: 9261-11596 kbps
- Audio: DTS/FLAC 5.1
- **Verdict**: KEEP all, very good quality

**Rocky Series** (4 films):
- ✅ Rocky I-IV present
- Bitrate: 9140-16039 kbps
- Audio: DTS 5.1
- **Verdict**: KEEP all, excellent quality

**Indiana Jones** (2 films):
- ✅ Raiders, Temple of Doom
- Missing: Last Crusade, Crystal Skull
- **Verdict**: KEEP, consider completing the collection

---

## Recommendations

### Immediate Actions

1. **Delete junk files** (~0.5GB):
   - `/mnt/storage/media/legacy-media/Movies/1080p/Rain.Man.1988.720p.BluRay.DTS.x264-CyTSuNee/[247]lvpjRnMn1988/place2useupload/Place2Use.net.Intro.mp4`
   - `/mnt/storage/media/legacy-media/Movies/1080p/Rain.Man.1988.720p.BluRay.DTS.x264-CyTSuNee/[247]lvpjRnMn1988/Belangrijk/Place2Use.net.Intro.mp4`
   - `/mnt/storage/media/legacy-media/old-downloads/Moana.2016.MULTI.1080p.HDLight.H264.AC3-LMPS-TiMnZb.mkv`

2. **Delete duplicate** (1GB):
   - Se7en.1995.REMASTERED.BluRay.720p.H264.mp4 (you have the 14.50GB version)

3. **Consider replacing** if you care about them:
   - The Sound of Music (1965) - Buy Blu-ray
   - The Parent Trap (1998) - Buy Blu-ray

### Shopping List (Optional - For Ultimate Quality)

If you want to upgrade to 4K or better quality:

**High Priority** (Movies you have in 720p that deserve 4K):
- Edge of Tomorrow
- Guardians of the Galaxy Vol. 2
- Pirates of the Caribbean: Dead Men Tell No Tales
- Star Wars: The Force Awakens

**Medium Priority** (Good quality but 4K would be nice):
- Moana (you have multiple versions, could consolidate to one 4K)
- Carol (if you love this film)

**Complete Collections**:
- Indiana Jones (missing Last Crusade & Crystal Skull)
- Alien series (you have 1, 2, 3 - consider getting 4, Prometheus, Covenant)

### Migration Strategy

For the 66 KEEP files:
1. Leave them in `/mnt/storage/media/legacy-media` for now
2. As you acquire 4K Blu-rays, rip them using your proper pipeline
3. Compare quality - if new rip is substantially better, move old version to archive
4. Your new library (`/mnt/storage/media/library`) should be your "gold standard" library
5. Legacy library becomes a fallback for content you haven't re-acquired

### Long-term Plan

**Tier 1 - Definite Keepers** (66 files, ~567GB):
- Move to `/mnt/storage/media/movies/` organized by FileBot
- These are home-theater quality and don't need replacement unless you want 4K

**Tier 2 - Review Later** (10 files, ~46.5GB):
- Keep in legacy-media for now
- Replace opportunistically (sales, streaming service downloads, etc.)

**Tier 3 - Delete or Replace** (7 files, ~17GB):
- Delete junk (2.5GB)
- Replace critical content (The Sound of Music if you value it)

---

## Technical Notes

**Quality Thresholds Used**:
- Excellent 1080p: 15000+ kbps video bitrate
- Good 1080p: 8000-15000 kbps
- Acceptable 1080p: 5000-8000 kbps
- Poor 1080p: <5000 kbps

**Audio Quality**:
- Best: DTS-HD, TrueHD, FLAC (lossless)
- Great: DTS, AC3 5.1+ (1500+ kbps)
- Good: AC3 5.1 (640 kbps)
- Poor: AAC/MP3 stereo

**Home Theater Recommendations**:
For your setup, prioritize:
1. Minimum 1080p actual resolution (not upscaled 720p)
2. Minimum 8000 kbps video bitrate
3. DTS or better audio codec
4. 5.1 or better surround sound

---

## Files

**Full Analysis Report**: `/tmp/legacy-media-analysis.csv`  
**Script Used**: `scripts/media/utilities/analyze-library-quality.sh`

To re-run this analysis:
```bash
ssh root@192.168.1.73  # analyzer container
/tmp/analyze-library-quality.sh /mnt/media/legacy-media
```

---

## Next Steps

1. Review this assessment
2. Delete the junk files identified above
3. Decide which "MAYBE" files you want to keep vs replace
4. Create a wishlist for physical media purchases (4K Blu-rays of favorites)
5. Consider organizing the 66 KEEP files into your main library
6. Set up a plan to gradually replace 720p content with proper Blu-ray rips

**Estimated Final State**:
- Keep: ~567GB of high-quality content
- Delete: ~17GB of junk/duplicates
- Decision pending: ~46.5GB of acceptable-but-not-ideal content
- **Total savings if you delete all non-KEEP**: ~64GB
- **Recommended**: Keep the 66 excellent files, delete the 7 junk files, review the 10 MAYBE files individually
