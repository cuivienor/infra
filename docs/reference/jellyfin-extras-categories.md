# Jellyfin Extras Categories - Quick Reference

A quick guide to understanding the different types of extras categories in Jellyfin.

## Standard Jellyfin Categories

Jellyfin recognizes these specific folder names for organizing movie/TV extras. **Folder names must use spaces** (not hyphens or underscores).

### Category Definitions

| Category | Description | Typical Examples |
|----------|-------------|------------------|
| **behind the scenes** | Making-of documentaries, production footage, set visits | "Making Of [Movie]", "Production Design", "Visual Effects Breakdown", "On Set with the Cast" |
| **deleted scenes** | Scenes cut from the final film | "Deleted Scene 01", "Extended Opening", "Alternate Ending" |
| **interviews** | Cast/crew interviews, Q&A sessions | "Director Interview", "Cast Roundtable", "Writer Commentary", "Actor Profile" |
| **featurettes** | Short documentary-style features about specific aspects | "Costume Design", "Musical Score", "Stunt Choreography", "Character Exploration" (5-20 min) |
| **scenes** | Specific scene analysis, alternate takes, raw footage | "Alternate Opening", "Extended Battle Scene", "Raw Scene Footage" |
| **shorts** | Short films, animated shorts, companion pieces | Pixar shorts (e.g., "Bao", "Piper"), standalone short films related to the movie |
| **clips** | Brief promotional clips, snippets, teasers | "30-Second Spot", "Clip Compilation", "Sneak Peek" (< 5 min) |
| **trailers** | Theatrical trailers, TV spots, teasers | "Theatrical Trailer", "Teaser Trailer", "International Trailer", "TV Spot" |
| **samples** | Sample footage, promotional previews | "Preview Reel", "Promotional Sample" |
| **extras** | Generic catch-all for uncategorized extras | Anything that doesn't fit other categories |
| **other** | Generic catch-all (same as extras) | Miscellaneous bonus content |

### Category vs Featurette vs Clip

**Common confusion** - Here's the breakdown:

- **Clip**: Very short (< 5 min), promotional in nature, single scene or moment
  - Example: "Opening Scene Preview", "Character Introduction Clip"

- **Featurette**: Medium length (5-20 min), documentary-style, focused topic
  - Example: "Building the Dragon: Visual Effects", "Designing Berk: Production Design"

- **Behind the Scenes**: Longer (10-60 min), comprehensive making-of, broader scope
  - Example: "The Making of How to Train Your Dragon", "From Page to Screen"

**Rule of thumb**: 
- If it's < 5 minutes and feels like a promo → `clips/`
- If it's 5-20 minutes and explores one topic → `featurettes/`
- If it's > 10 minutes and shows production process → `behind the scenes/`

### Scenes vs Deleted Scenes

- **deleted scenes**: Content that was filmed but cut from the final movie
  - Example: "Deleted Opening", "Cut Character Introduction"

- **scenes**: Alternate versions, extended versions, or raw scene footage from scenes that ARE in the movie
  - Example: "Extended Final Battle", "Alternate Take: Dragon Flight"

If a scene was removed entirely → `deleted scenes/`  
If it's a different version of a scene that's in the movie → `scenes/`

### Interviews vs Featurettes

- **interviews**: Direct Q&A, talking heads, conversation format
  - Example: "Director Commentary", "Cast Interview", "Actor Roundtable"

- **featurettes**: Produced documentary-style with narration, multiple sources, editing
  - Example: "Exploring the World of Dragons" (has interviews + footage + narration)

If it's just people talking to camera → `interviews/`  
If it's a produced mini-documentary → `featurettes/`

### Shorts vs Clips

- **shorts**: Complete standalone short films (often with credits)
  - Example: Pixar's "Bilby", "Piper", "Bao"

- **clips**: Brief excerpts or promotional content
  - Example: "Sneak Peek", "Character Introduction"

If it has opening/closing credits and tells a complete story → `shorts/`  
If it's a promotional excerpt or snippet → `clips/`

---

## Practical Decision Tree

When organizing an extra, ask yourself:

1. **Is it a standalone short film with credits?** → `shorts/`
2. **Is it a trailer/teaser/TV spot?** → `trailers/`
3. **Was this scene cut from the final movie?** → `deleted scenes/`
4. **Is it an alternate/extended version of a scene that's IN the movie?** → `scenes/`
5. **Is it people talking directly to camera (Q&A style)?** → `interviews/`
6. **Is it < 5 minutes and promotional?** → `clips/`
7. **Is it 5-20 minutes about one specific topic?** → `featurettes/`
8. **Is it > 10 minutes about the making-of/production?** → `behind the scenes/`
9. **None of the above?** → `extras/` or `other/`

---

## Common Blu-ray Extras → Jellyfin Categories

| Blu-ray Label | Jellyfin Category | Notes |
|---------------|-------------------|-------|
| "The Making Of..." | `behind the scenes` | Long-form production documentary |
| "Deleted Scenes" | `deleted scenes` | Pretty straightforward |
| "Gag Reel" | `extras` or `behind the scenes` | Bloopers/outtakes |
| "Audio Commentary" | `extras` | Can't categorize easily, just leave with main movie |
| "Featurette: [Topic]" | `featurettes` | If under 20 min and focused |
| "Character Profile" | `featurettes` or `interviews` | Depends on format |
| "Storyboard Comparison" | `behind the scenes` | Production process |
| "Concept Art Gallery" | N/A | Jellyfin doesn't handle image galleries well |
| "Theatrical Trailer" | `trailers` | Obvious |
| "Director Interview" | `interviews` | Q&A format |
| "Visual Effects Breakdown" | `featurettes` | Focused technical topic |
| "Music Video" | `clips` or `extras` | Music videos related to movie |
| Pixar Short Film | `shorts` | Complete short film |

---

## Your "How to Train Your Dragon" Example

Based on Blu-ray.com listing:

```
How to Train Your Dragon: The Hidden World (2019)
├── behind the scenes/
│   ├── How to Train Your Dragon in Real Life.mkv      (10 min - exploration of real dragons)
│   └── Growing Up with Dragons.mkv                    (12 min - making-of style)
├── deleted scenes/
│   └── Deleted Scenes.mkv                             (8 min - cut content)
└── shorts/
    └── Bilby.mkv                                       (8 min - complete short film with credits)
```

**Rationale**:
- "How to Train Your Dragon in Real Life" - Documentary-style exploration → `behind the scenes/`
- "Growing Up with Dragons" - Making-of the trilogy → `behind the scenes/`
- "Deleted Scenes" - Cut from movie → `deleted scenes/`
- "Bilby" - Standalone DreamWorks short film → `shorts/`

---

## Tips

- **When in doubt**: Use `extras/` - it's the catch-all
- **Don't overthink**: Jellyfin users just want to find bonus content, exact category is less important
- **Be consistent**: Pick a categorization style and stick with it across your library
- **Descriptive names matter more**: `Making Of.mkv` vs `Visual Effects Breakdown.mkv` is more important than which subfolder it's in
- **Folder names need spaces**: `behind the scenes` not `behind-the-scenes`

---

**Last updated:** 2025-11-13
