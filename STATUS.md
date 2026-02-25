# Social Marketer - Project Status

## Version: **2.3** (Build 3)

## Current Status: ✅ **TIKTOK CONNECTOR ADDED - 7 PLATFORMS ACTIVE**

**GitHub:** <https://github.com/Quasaur/social-marketer>

Social Marketer is a native macOS application that automates content distribution from The Book of Wisdom to social media platforms. **Queue-driven posting is now fully implemented!**

## What's Working

### Core Features (v2.2)

| Feature | Status | Notes |
|---------|--------|-------|
| **Queue-Driven Posting** | ✅ **NEW** | Auto-populates from RSS, one post per day |
| Content Library | ✅ **NEW** | Caches ALL Thoughts, Quotes, Passages with post tracking |
| Image/Video Post Tracking | ✅ **NEW** | Per-content-item stats (📷 / 🎬 counts) |
| YouTube Uploads | ✅ **LIVE** | Videos upload as **Public**, no Studio intervention |
| Video Generation | ✅ **LIVE** | Auto-starts Social Effects, generates Shorts |
| Video Reuse | ✅ Working | Checks for existing videos before generating |
| Post Queue | ✅ Working | Auto-populated from RSS, scheduled posts |
| RSS Integration | ✅ Working | Fetches from all wisdombook.life feeds |
| Platform Connections | ✅ Working | OAuth for all platforms |
| Test Posts (All Platforms) | ✅ Working | Uses scheduled post from queue |
| Dashboard Analytics | ✅ Working | Real-time health monitoring |
| Debug Mode | ✅ Working | Toggle-controlled logging |
| Preferred Media Preferences | ✅ Working | Strict enforcement (no fallbacks) |

### Platform Status

| Platform | Connect | Test Post | Auto-Post | Status |
|----------|---------|-----------|-----------|--------|
| YouTube | ✅ | ✅ | ✅ | **FULLY OPERATIONAL** |
| Twitter/X | ✅ | ✅ | ✅ | **Queue-driven ready** |
| LinkedIn | ✅ | ✅ | ✅ | **Queue-driven ready** |
| Facebook | ✅ | ✅ | ✅ | **Queue-driven ready** |
| Instagram | ✅ | ✅ | 🔲 | Queue-driven, API updated to v25.0 |
| Pinterest | ✅ | ✅ | ✅ | **Queue-driven ready** |
| TikTok | ✅ | ✅ | 🔲 | **NEW - Content Posting API** |

Legend: ✅ Working | 🔲 Not tested | ❌ Not working

## Architecture (Queue-Driven)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Social Marketer v2.2                                │
│                     (macOS SwiftUI App)                                  │
├─────────────────────────────────────────────────────────────────────────┤
│  Content Library → Post Queue → PostScheduler → PlatformRouter           │
│        ↑                                              ↓                  │
│   RSS Feeds                              SocialEffectsService            │
│   (thoughts/quotes/                             ↓                        │
│    passages)                      VideoGenerator + QuoteGraphicGenerator │
│                                              ↓                           │
│              Platform Connectors → YouTube/Twitter/LinkedIn/             │
│                                    Instagram/Pinterest/Facebook          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Social Effects Server Lifecycle

Social Effects now runs as a **persistent background service**:

| Phase | Trigger | Action |
|-------|---------|--------|
| **Start** | App Launch (`init()`) | `SocialEffectsService.ensureServerRunning()` starts the API server |
| **Run** | During app lifetime | Server stays running on port 5390, handles all video generation |
| **Stop** | App Quit (`applicationWillTerminate`) | Graceful shutdown via `SocialEffectsService.shutdown()` |

**Benefits:**
- Faster video generation (no server startup per video)
- Reduced resource overhead (single server instance)
- Cleaner architecture (lifecycle managed at app level)

## Key Components

### Services

| Service | Purpose |
|---------|---------|
| `PostScheduler` | Orchestrates posting, manages launchd, queue processing |
| `VideoGenerator` | Interface to Social Effects for video creation |
| `SocialEffectsProcessManager` | Manages Social Effects server lifecycle |
| `ConnectionHealthService` | Monitors external APIs and local services |
| `PlatformRouter` | Routes posts to appropriate connectors |

### Data Models

- **Post** - Scheduled/published posts (Core Data)
- **Platform** - Social media platform configurations
- **PostLog** - Post result logging for analytics
- **CachedWisdomEntry** - Cached RSS content

## YouTube Integration - FULLY AUTOMATED ✅

The complete flow now works without manual intervention:

```
1. User clicks "Test Post" (or scheduled post triggers)
        ↓
2. Social Marketer fetches content from Queue or RSS
        ↓
3. Checks for existing video, generates if needed
   - Auto-starts Social Effects if not running
   - Video saved to external drive
        ↓
4. Uploads to YouTube with proper metadata:
   - selfDeclaredMadeForKids: false
   - categoryId: 27 (Education)
   - containsSyntheticMedia: false
   - privacyStatus: public
        ↓
5. ✅ Video appears on YouTube as **PUBLIC**
```

### Required Metadata for Full Automation

YouTube requires these fields for public uploads:

```swift
"status": [
    "privacyStatus": "public",
    "selfDeclaredMadeForKids": false,  // Critical!
    "embeddable": true,
    "publicStatsViewable": true,
    "license": "youtube"
],
"contentDetails": [
    "containsSyntheticMedia": false
]
```

## Recent Updates (February 2026) - v2.3 RELEASE

### Major Achievements (v2.3)

1. **TikTok Connector** - New Content Posting API integration with OAuth 2.0 + PKCE
2. **YouTube Connection State Fix** - Now shows "Disconnect" persistently like other platforms
3. **TikTok Media Preference** - Respects Settings; skips TikTok if set to image (video only)
4. **TikTok URL Verification Docs** - Complete GoDaddy DNS TXT record instructions
5. **Platform Tier Updates** - TikTok moved from "API Available" to active platforms list

### Major Achievements (v2.2)

1. **Queue-Driven Architecture** - Complete redesign with Post Queue as single source of truth
2. **Content Library** - Caches ALL Thoughts, Quotes, Passages from RSS feeds
3. **Image/Video Post Tracking** - Per-content-item stats showing 📷 (image) / 🎬 (video) counts
4. **Auto-Population** - Queue automatically fills from RSS when empty (one post per day)
5. **Test Posts Using Scheduled Content** - All Test Post/Pin buttons use scheduled post from queue
6. **Smart Test Post Auto-Populate** - Test posts auto-fill empty queue WITHOUT posting to all platforms
7. **Strict Media Preferences** - No fallbacks (video preference + no video = error in Recent Errors)
8. **OAuth Port Fix** - Changed from 5390 to unique ports (9090-9094) to avoid Social Effects conflict
9. **RSS Parsing Optimization** - Skip expensive extractBookName() for Thoughts (no book references)
10. **Social Effects Attribution** - Send book name (quotes) and Bible reference (passages) to Social Effects API

### Technical Improvements (v2.3)

- **TikTok OAuth:** PKCE-based authentication with localhost callback (port 9095)
- **TikTok Video Upload:** Direct video posting via Content Posting API
- **YouTube Connection State:** Simplified to credential-based (not token-based) for consistent UX
- **TikTok Skip Logic:** PlatformRouter skips TikTok when media preference = image
- **Build Version:** Updated to v2.3 (Build 3)

### Technical Improvements (v2.2)

- **Queue-Driven Workflow:** `processQueue()` now auto-populates and processes scheduled posts
- **Content Library Stats:** `postedImageCount` and `postedVideoCount` in Core Data
- **Test Post Unification:** All platforms use `getScheduledPostForToday()` helper
- **Test Post Auto-Populate:** `getScheduledPostForToday()` now calls `autoPopulateQueueFromRSS()` when queue is empty
- **Video Preference Enforcement:** Removed all video-to-image fallbacks
- **RSS Feed Integration:** Auto-populates from thoughts, quotes, passages feeds
- **RSS Optimization:** `extractBookName()` only called for Quotes and Passages (not Thoughts)
- **Social Effects API:** Added `source` field to video generation request (book name or Bible reference)
- **Build Version:** Updated to v2.2 (Build 2)

### Previous Achievements (v1.x)

- **YouTube Public Uploads** - Videos upload as Public without Studio intervention
- **Automatic Social Effects Startup** - App starts video generation service on launch
- **Video Discovery** - Reuses existing videos instead of regenerating
- **Configuration Centralization** - All hardcoded values moved to `AppConfiguration`
- **Dependency Injection Framework** - Protocol-based service abstraction layer

## File Locations

| Type | Path |
|------|------|
| App Bundle | `~/Library/Developer/Xcode/DerivedData/.../Social Marketer.app` |
| Core Data | `~/Library/Group Containers/group.com.wisdombook.SocialMarketer/` |
| Social Effects Binary | `~/Developer/social-effects/.build/debug/SocialEffects` |
| Generated Videos | `/Volumes/My Passport/social-media-content/social-effects/video/api/` |

## Dependencies

- **Social Effects** (local HTTP API on port 5390)
- **YouTube Data API v3** (OAuth 2.0)
- **macOS 14.0+** (Sonoma)
- **Xcode 15.0+** (for development)

## Configuration

No build-time configuration required. All settings are runtime:

- Platform credentials → **Keychain**
- Schedule settings → **UserDefaults**
- Debug mode → **Settings toggle**

## Known Issues

| Issue | Status | Workaround |
|-------|--------|------------|
| OAuth token expiration | Expected | Disconnect/reconnect platform |
| Social Effects crash | Rare | Restart Social Effects manually |

## Next Steps / Future Enhancements

- [x] TikTok Connector (submitted for approval) ✅
- [ ] Test and enable remaining platforms (Twitter, LinkedIn, Instagram, Pinterest, TikTok)
- [ ] Add batch posting from Queue
- [ ] Implement analytics export
- [ ] Add thumbnail customization
- [ ] Background video selection UI
- [ ] TikTok photo posting (when API supports it)

## Testing Checklist

### Core Features (v2.2)
- [x] Queue auto-population from RSS
- [x] Content Library with image/video tracking
- [x] One post per day scheduling
- [x] Test Posts use scheduled content (all platforms)
- [x] Test Posts auto-populate queue (without posting to all platforms)
- [x] Strict media preference enforcement
- [x] OAuth port conflicts resolved

### Platform Tests
- [x] YouTube upload as Public
- [x] YouTube Test Post (scheduled content)
- [x] YouTube persistent "Disconnect" button
- [x] Twitter/X Test Post (scheduled content)
- [x] LinkedIn Test Post (scheduled content)
- [x] Facebook Test Post (scheduled content)
- [x] Pinterest Test Pin (scheduled content)
- [x] Instagram Test Post (video) - **API updated, ready to test**
- [ ] TikTok Test Video (scheduled content) - **NEW**
- [ ] TikTok Media Preference (image = skip) - **NEW**

### Previous Tests (v1.x)
- [x] Video generation integration
- [x] Auto-start Social Effects
- [x] Video reuse (existing video found)
- [x] Debug Mode toggle controls logging
- [x] Dashboard health monitoring

## Contact

For questions or support: <devcalvinlm@gmail.com>

---

**Status:** ✅ **PRODUCTION READY** - YouTube automation fully operational!
