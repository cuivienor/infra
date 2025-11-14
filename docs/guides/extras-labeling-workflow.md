# Extras Labeling Workflow

This guide explains how to properly identify, label, and organize Blu-ray extras (special features) in your media pipeline.

## The Challenge

**FileBot cannot automatically identify specific extras** for movies. Here's why:

- **No database tracking**: TheMovieDB, IMDb, and TheTVDB don't catalog disc bonus content
- **No standardization**: Every Blu-ray release has different special features
- **No embedded metadata**: MakeMKV rips don't include descriptive titles for extras

This means you'll need to **manually identify and label** extras before or after transcoding.

---

## Current Workflow Issues

### What Happens Now

1. **MakeMKV rips** create files like:
   ```
   title_t00.mkv  (main movie)
   title_t01.mkv  (unknown extra)
   title_t02.mkv  (unknown extra)
   title_t03.mkv  (unknown extra)
   ```

2. **organize-and-remux-movie.sh** categorizes by duration/size:
   - Main features: `>30min AND >5GB` → stays in root
   - Extras: `<30min OR <5GB` → goes to `extras/` folder

3. **FileBot** moves to library:
   ```
   /mnt/library/movies/Movie Name (Year)/
       Movie Name (Year).mkv
       extras/
           title_t01.mkv  ← Still generic names!
           title_t02.mkv
           title_t03.mkv
   ```

### The Problem

In Jellyfin, you see:
- ✅ Movie plays correctly
- ❌ Extras section shows "title_t01", "title_t02", etc.
- ❌ No idea which extra is which without playing each one

---

## Recommended Workflow: Label in Jellyfin Library

**Best Practice**: Let your scripts handle extras automatically, then **organize them in the final library** after FileBot completes.

### Why This Approach Works Best

1. **Your scripts already work** - They correctly identify and separate extras
2. **No re-encoding needed** - Extras are already transcoded and in the library
3. **Preview in Jellyfin** - Play extras directly in Jellyfin to identify them
4. **One-time organization** - Rename and categorize in final location

---

## Solution 1: Organize in Jellyfin Library (Recommended)

### Step-by-Step Workflow

#### 1. Complete Normal Workflow First

Let your scripts handle everything automatically:

1. **Rip** → creates generic `title_t*.mkv` files
2. **Organize & Remux** → separates main movie from extras into `extras/` folder
3. **Transcode** → processes everything
4. **FileBot** → moves to Jellyfin library

**Result after FileBot:**
```
/mnt/storage/media/library/movies/Movie Name (Year)/
    Movie Name (Year).mkv
    extras/
        title_t01.mkv
        title_t02.mkv
        title_t03.mkv
```

#### 2. Look Up Extras on Blu-ray.com (Optional but Helpful)

Visit https://www.blu-ray.com/ and search for your movie to see what extras are included and their approximate durations. This helps you identify files faster.

#### 3. Preview and Identify Extras in Jellyfin

**Best approach**: Use Jellyfin itself to preview extras!

1. Open Jellyfin web UI
2. Navigate to your movie
3. Scroll to "Special Features" section
4. Play each extra (first 10-30 seconds is enough)
5. Note what each one is

**Alternative**: Preview via SSH
```bash
ssh root@192.168.1.73  # ct303 analyzer
cd /mnt/storage/media/library/movies/Movie\ Name\ \(Year\)/extras/

# Quick preview
mpv --start=0 --length=30 title_t01.mkv
```

#### 4. Rename and Organize into Categories

Once you know what each extra is, organize them:

```bash
ssh root@192.168.1.73  # ct303 analyzer
cd /mnt/storage/media/library/movies/Movie\ Name\ \(Year\)/

# Create Jellyfin standard folders (note the spaces!)
mkdir "behind the scenes" "deleted scenes" "interviews" "trailers" "shorts"

# Rename and move extras into appropriate categories
mv extras/title_t01.mkv "behind the scenes/Making Of The Hidden World.mkv"
mv extras/title_t02.mkv "behind the scenes/Growing Up with Dragons.mkv"
mv extras/title_t03.mkv "deleted scenes/Deleted Scenes.mkv"
mv extras/title_t04.mkv "shorts/Bilby.mkv"

# Remove empty extras folder
rmdir extras/
```

**Standard Jellyfin folder names** (must use spaces, not hyphens):
- `behind the scenes` - Making-of documentaries, production footage
- `deleted scenes` - Scenes cut from the final film
- `interviews` - Cast/crew Q&A, talking heads
- `featurettes` - Short documentary features (5-20 min)
- `scenes` - Alternate/extended versions of scenes in the movie
- `trailers` - Theatrical trailers, teasers, TV spots
- `shorts` - Complete standalone short films
- `clips` - Brief promotional clips (< 5 min)
- `samples` - Preview footage
- `extras` - Generic catch-all
- `other` - Generic catch-all

**Not sure which category?** See [Jellyfin Extras Categories Reference](../reference/jellyfin-extras-categories.md) for detailed definitions and examples.

#### 5. Refresh Jellyfin Metadata

Tell Jellyfin to detect the changes:

1. Jellyfin Dashboard → Libraries
2. Click "Scan All Libraries" (or just scan Movies library)
3. Navigate back to your movie
4. Special Features now show in organized categories!

**Result:**
```
/mnt/storage/media/library/movies/How to Train Your Dragon (2019)/
    How to Train Your Dragon (2019).mkv
    behind the scenes/
        Making Of The Hidden World.mkv
        Growing Up with Dragons.mkv
    deleted scenes/
        Deleted Scenes.mkv
    shorts/
        Bilby.mkv
```

In Jellyfin UI, you'll see:
- **Behind the Scenes** (2 items)
- **Deleted Scenes** (1 item)
- **Shorts** (1 item)

---

## Solution 2: Pre-Transcode Labeling (Advanced)

If you prefer to rename extras **before transcoding** to have meaningful names throughout the pipeline, you can do so. This adds extra work upfront but gives you better tracking.

### When to Use This

- You want to track extras through the entire pipeline
- You're ripping many discs and want consistent naming early
- You prefer to preview on the ripper container before transcoding

### Quick Pre-Transcode Workflow

```bash
# After ripping on ct302
ssh ct303  # Switch to analyzer
cd /mnt/staging/1-ripped/movies/Movie_Name_*/

# Preview each extra
mpv --start=0 --length=30 title_t01.mkv

# Rename immediately
mv title_t01.mkv "Making_Of.mkv"
mv title_t02.mkv "Deleted_Scenes.mkv"

# Continue normal workflow
./run-bg.sh ./organize-and-remux-movie.sh /mnt/staging/1-ripped/movies/Movie_Name_*/
```

Files will retain these names through transcode and into Jellyfin. You can still organize into subdirectories later.

---

## Solution 3: Reference Blu-ray Database

Some websites catalog Blu-ray extras. You can cross-reference before reviewing:

### Blu-ray.com

1. Visit: https://www.blu-ray.com/
2. Search for your movie
3. Click "Special Features" tab
4. Compare duration/order with your ripped files

**Example**: [How to Train Your Dragon: The Hidden World](https://www.blu-ray.com/movies/How-to-Train-Your-Dragon-The-Hidden-World-Blu-ray/234689/)

```
Special Features:
  - How to Train Your Dragon in Real Life (10:04)
  - Growing Up with Dragons (12:36)
  - Deleted Scenes (8:21)
  - Bilby (Short Film, 8:04)
```

Now match durations:
```bash
title_t01.mkv: 10min → "How_to_Train_Your_Dragon_in_Real_Life.mkv"
title_t02.mkv: 12min → "Growing_Up_with_Dragons.mkv"
title_t03.mkv: 8min  → "Deleted_Scenes.mkv"
title_t04.mkv: 8min  → "Bilby_Short_Film.mkv"
```

### Other Resources

- **DVDizzy.com**: Disney/Pixar Blu-ray special features
- **High-Def Digest**: Blu-ray reviews with special features lists
- **DVD Talk**: Forum discussions about disc contents

---



---

## Practical Tips

### Organization Strategy

- **Don't over-think it** - Let your scripts handle the heavy lifting
- **Organize in Jellyfin** - Easier to preview and reorganize in final location
- **Use Blu-ray.com** - Cross-reference to identify extras faster
- **Batch processing** - Organize extras for multiple movies in one session

### Naming Conventions

- ✅ **Use spaces or underscores**: `Making Of.mkv` or `Making_Of.mkv`
- ✅ **Be descriptive**: `Director Commentary Full Film.mkv`
- ✅ **Match Blu-ray names** when possible for clarity
- ❌ **Avoid special characters**: No `:`, `/`, `?`, `*` in filenames

### Jellyfin Folder Names (Critical!)

- ✅ **Use spaces**: `behind the scenes` (not `behind-the-scenes` or `behindthescenes`)
- ✅ **Any capitalization works**: `Behind The Scenes`, `BEHIND THE SCENES`, `behind the scenes`
- ✅ **Exact folder names only**: Must match Jellyfin's supported list exactly

### Time Savings

- **No pre-transcode work** - Let scripts handle everything automatically
- **Preview in Jellyfin** - Use the actual player you'll watch on
- **One-time organization** - Files are already transcoded and in final location
- **Batch organize** - Do multiple movies at once when you have time

---

## Automation Limitations

**Why can't this be automated?**

1. **No metadata in rip**: MakeMKV doesn't preserve disc menu structure or titles
2. **No online database**: TheMovieDB/IMDb don't track Blu-ray bonus content
3. **Variable naming**: Disc publishers use inconsistent naming (e.g., "The Making Of" vs "Behind the Scenes")
4. **OCR unreliable**: Title cards at the start of extras aren't standardized enough for OCR

**Potential future improvements**:
- Script to auto-preview first 10 seconds of each extra
- OCR of title screens (would require tesseract, ffmpeg, custom script)
- Community database of Blu-ray extras (doesn't exist yet)

For now, **manual review is the gold standard** for properly labeled extras.

---

## Complete Workflow Summary

### Recommended: Organize After FileBot

1. **Rip** → Generic `title_t*.mkv` files created
2. **Merge** (if multi-disc) → All files in one folder
3. **Organize & Remux** → Main movie separated from extras automatically
4. **Transcode** → Everything processed
5. **FileBot** → Moved to library with `extras/` folder
6. **Preview in Jellyfin** → Play each extra to identify it
7. **Organize** → Create Jellyfin folders and move extras into categories
8. **Refresh metadata** → Jellyfin detects new organization
9. **Done!** → Properly categorized extras in Special Features

### Alternative: Pre-Transcode Labeling

1. **Rip** → Generic files created
2. **Merge** (if multi-disc)
3. **Preview and rename** → Give extras descriptive names
4. **Organize & Remux** → Scripts preserve renamed files
5. **Transcode** → Process with good names
6. **FileBot** → Move to library
7. **Organize** (optional) → Move into Jellyfin category folders
8. **Done!**

---

**Last updated:** 2025-11-13
