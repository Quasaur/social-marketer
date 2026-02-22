# Social Marketer - Project Status

## Current Status: ✅ **FULLY OPERATIONAL**

**GitHub:** <https://github.com/Quasaur/social-marketer>

Social Marketer is a native macOS application that automates content distribution from The Book of Wisdom to social media platforms. **YouTube uploads are now fully automated with public visibility!**

## What's Working

### Core Features

| Feature | Status | Notes |
|---------|--------|-------|
| YouTube Uploads | ✅ **LIVE** | Videos upload as **Public**, no Studio intervention |
| Video Generation | ✅ **LIVE** | Auto-starts Social Effects, generates Shorts |
| Video Reuse | ✅ Working | Checks for existing videos before generating |
| Post Queue | ✅ Working | Schedule and manage pending posts |
| RSS Integration | ✅ Working | Fetches from wisdombook.life feeds |
| Platform Connections | ✅ Working | OAuth for all platforms |
| Dashboard Analytics | ✅ Working | Real-time health monitoring |
| Debug Mode | ✅ Working | Toggle-controlled logging |

### Platform Status

| Platform | Connect | Test Post | Auto-Post | Status |
|----------|---------|-----------|-----------|--------|
| YouTube | ✅ | ✅ | ✅ | **FULLY OPERATIONAL** |
| Twitter/X | ✅ | 🔲 | 🔲 | OAuth ready, needs testing |
| LinkedIn | ✅ | 🔲 | 🔲 | OAuth ready, needs testing |
| Instagram | ✅ | 🔲 | 🔲 | OAuth ready, needs testing |
| Pinterest | ✅ | 🔲 | 🔲 | OAuth ready, needs testing |

Legend: ✅ Working | 🔲 Not tested | ❌ Not working

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Social Marketer                                   │
│                   (macOS SwiftUI App)                                │
├─────────────────────────────────────────────────────────────────────┤
│  Dashboard → Queue → PostScheduler → PlatformRouter                  │
│                                              ↓                       │
│              SocialEffectsService (HTTP client)                      │
│                                              ↓                       │
│              VideoGenerator → Social Effects API (localhost:5390)    │
│                                              ↓                       │
│              Platform Connectors → YouTube API                       │
└─────────────────────────────────────────────────────────────────────┘
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

## Recent Updates (February 2026)

### Major Achievements

1. **YouTube Public Uploads** - Videos now upload as Public without Studio intervention
2. **Automatic Social Effects Startup** - App starts video generation service on launch
3. **Video Discovery** - Reuses existing videos instead of regenerating
4. **Debug Mode Toggle** - All debug logging controlled by Settings toggle
5. **Error Log Integration** - Detailed logging visible in Dashboard

### Technical Improvements

- Fixed `Content-Length` header for HTTP requests
- Added process liveness checking for Social Effects
- Improved error handling with specific error messages
- Added comprehensive debug logging (toggle-controlled)

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

- [ ] Test and enable remaining platforms (Twitter, LinkedIn, Instagram, Pinterest)
- [ ] Add batch posting from Queue
- [ ] Implement analytics export
- [ ] Add thumbnail customization
- [ ] Background video selection UI

## Testing Checklist

- [x] YouTube upload as Public
- [x] Video generation integration
- [x] Auto-start Social Effects
- [x] Video reuse (existing video found)
- [x] Debug Mode toggle controls logging
- [x] Dashboard health monitoring
- [ ] Twitter upload
- [ ] LinkedIn upload
- [ ] Instagram upload
- [ ] Pinterest upload

## Contact

For questions or support: <devcalvinlm@gmail.com>

---

**Status:** ✅ **PRODUCTION READY** - YouTube automation fully operational!
