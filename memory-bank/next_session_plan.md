# Social Marketer - Next Session Plan

**Date:** February 22, 2026  
**Current Version:** 2.2 (Build 2)  
**Status:** Queue-driven architecture implemented, Instagram Test Post pending verification

---

## Current State (End of Feb 22 Session)

### ✅ Completed
- Queue-driven posting architecture implemented
- All Test Post/Pin buttons use scheduled content from queue
- Content Library fetches from all RSS feeds (thoughts, quotes, passages, daily)
- Image/Video post tracking in Core Data (`postedImageCount`, `postedVideoCount`)
- Strict media preference enforcement (no fallbacks)
- OAuth port conflicts resolved (9090-9094)
- Version updated to 2.2

### ⚠️ Pending
- Instagram Test Post button verification (scheduled for tomorrow)
- Content Library architecture decision (see below)

---

## Proposed Architecture Change: Posted-Only Content Library

### Problem with Current Design
Content Library fetches from RSS feeds (limited to ~200 items due to 50-item per feed limit). This creates:
- Incomplete tracking for older content
- Unnecessary complexity (pre-populating items that may never be posted)
- Refresh button confusion

### Proposed Solution
**Content Library becomes "Posted Content Archive"**

```
RSS Feeds → Post Queue → Post to Platforms → Create/Update in Content Library
                                                    ↓
                                         (Posted Content Archive)
                                                    ↓
                              Tracks: Image count, Video count, Last posted
```

### Key Changes

| Aspect | Current | Proposed |
|--------|---------|----------|
| Content Source | RSS feeds (pre-populated) | Posted content (post-populated) |
| Refresh Button | Yes (fetches RSS) | **Remove** |
| Item Limit | 200 (RSS limit) | Unlimited (grows with posts) |
| Tracking Accuracy | Only if item cached | **Always accurate** (posted = tracked) |
| Library Purpose | RSS cache | **Posted archive with stats** |

### Implementation Plan

1. **Remove `ContentService.refreshContent()`**
   - No more RSS fetching for Library
   - Remove Refresh button from Content Library UI

2. **Modify `PlatformRouter.postToAll()`**
   - On successful post: Create/update `CachedWisdomEntry`
   - Call `markPostedAsImage()` or `markPostedAsVideo()`
   - Store: title, content, link, category, post counts, last posted date

3. **Simplify `CachedWisdomEntry`**
   - Remove RSS-specific fields
   - Keep: id, title, content, link, category, postedImageCount, postedVideoCount, lastPostedAt

4. **Update Content Library UI**
   - Remove "Refresh" button
   - Show: Posted content only with 📷 / 🎬 counters
   - Sort by: Last posted date (most recent first)

### Benefits

1. **Simpler Code** - Remove RSS parsing for Library, `ContentService`
2. **No RSS Limits** - Library grows organically with usage
3. **Accurate Tracking** - Every item has actual post history
4. **Performance** - Smaller, relevant dataset
5. **Clear Purpose** - Library shows "What have I posted?"

---

## Tomorrow's Testing Checklist

### Immediate (Before Code Changes)
- [ ] Test Instagram Test Post button with video preference
- [ ] Verify error appears in Recent Errors if video generation fails
- [ ] Confirm no fallback to image occurs

### After Implementing Posted-Only Library
- [ ] Verify Content Library shows only posted content
- [ ] Test image post tracking increments 📷 counter
- [ ] Test video post tracking increments 🎬 counter
- [ ] Confirm queue auto-population still works
- [ ] Verify scheduled posts still process correctly

---

## Open Questions

1. **Instagram Video Posting** - Does the current implementation work, or do we need API permission changes?

2. **Posted-Only Library** - Should we keep the existing entries in Content Library (migrate) or start fresh?

3. **Queue Population** - Keep current RSS-based queue population, or populate queue from AuraDB directly in future?

---

## Files to Modify (Posted-Only Library)

| File | Changes |
|------|---------|
| `ContentService.swift` | Remove or simplify - no RSS fetching for Library |
| `ContentBrowserView.swift` | Remove Refresh button, update UI for posted-only view |
| `PlatformRouter.swift` | Add logic to create/update Library entries on post success |
| `CachedWisdomEntry+CoreDataClass.swift` | May simplify, remove RSS-specific fields |
| `PostScheduler.swift` | Queue population stays (RSS), just Library changes |

---

## Notes

- The Queue (Post entity) remains RSS-driven - this is working well
- Only the Content Library changes from "RSS cache" to "Posted archive"
- This eliminates the 50-item RSS limitation for tracking purposes
- All posted content will have accurate image/video post counts

---

**Ready to implement when you return!**
