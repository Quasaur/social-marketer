# AGENTS.md - Developer Guide for Social Marketer

This file provides context for AI assistants and developers working on the Social Marketer project.

## Project Overview

**Social Marketer** is a native macOS application built with SwiftUI that automates content distribution from The Book of Wisdom (wisdombook.life) to social media platforms. It integrates with Social Effects for video generation.

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────┐
│                    Social Marketer                       │
│                   (SwiftUI macOS App)                    │
├─────────────────────────────────────────────────────────┤
│  Views          │  Dashboard, Queue, Platform Settings  │
│  Services       │  PostScheduler, VideoGenerator        │
│  Models         │  Post, Platform, PostLog (Core Data)  │
│  Connectors     │  YouTube, Twitter, LinkedIn, etc.     │
└─────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
    │Social Effects│ │  YouTube    │ │  Twitter    │
    │ (Local API)  │ │   API       │ │   API       │
    └─────────────┘ └─────────────┘ └─────────────┘
```

### Key Services

| Service | Purpose | File |
|---------|---------|------|
| `PostScheduler` | Orchestrates posting, manages launchd, queue processing | `PostScheduler.swift` |
| `SocialEffectsService` | Interface to Social Effects for video creation | `SocialEffectsService.swift` |
| `SocialEffectsProcessManager` | Manages Social Effects server lifecycle | `SocialEffectsProcessManager.swift` |
| `ConnectionHealthService` | Monitors external APIs and local services | `ConnectionHealthService.swift` |
| `PlatformRouter` | Routes posts to appropriate connectors | `PlatformRouter.swift` |

### Data Flow

1. **Content Ingestion**: RSS fetch → Core Data (`Post` entity)
2. **Video Generation**: WisdomEntry → Social Effects → MP4 file
3. **Posting**: Post + Video → PlatformRouter → Connector APIs
4. **Logging**: All operations → ErrorLog + PostLog

### Social Effects Server Lifecycle

Social Effects runs as a **persistent background service** while Social Marketer is open:

```
App Launch (SocialMarketerApp.init)
    ↓
startSocialEffectsService() → SocialEffectsService.ensureServerRunning()
    ↓
Social Effects API Server starts on port 5390 (if not already running)
    ↓
[Server runs continuously...]
    ↓
Video Generation Requests (via HTTP POST /generate)
    ↓
[App continues running...]
    ↓
User Quits App → SocialMarketerAppDelegate.applicationWillTerminate()
    ↓
Graceful shutdown of Social Effects server
```

**Key Points:**
- Server is started once on app launch (in `init()`)
- Server stays running for all video generation requests
- Server is gracefully shut down when app terminates (via `AppDelegate`)
- `SocialEffectsService.ensureServerRunning()` is idempotent - safe to call multiple times
- Each video generation request reuses the same running server instance

## Development Guidelines

### Adding a New Platform

1. Create connector in `Services/Connectors/`
2. Implement `VideoPlatformConnector` protocol
3. Add to `PlatformRouter.connectorFor()`
4. Update `ConnectionHealthService` endpoints
5. Add platform seed in `SocialMarketerApp.seedPlatformsIfNeeded()`

### Video Generation Flow

```swift
// 1. Check for existing video
if let existingURL = findExistingVideo(for: entry.title) {
    return existingURL  // Reuse existing
}

// 2. Generate new video via Social Effects
let videoURL = try await videoGen.generateVideo(entry: entry)

// 3. Upload with platform-specific metadata
let result = try await connector.postVideo(videoURL, caption: caption)
```

### Error Handling

Always log to ErrorLog for dashboard visibility:

```swift
ErrorLog.shared.log(
    category: "YouTube",  // Platform or service name
    message: "Upload failed",
    detail: error.localizedDescription
)
```

## Important Paths

| Path | Purpose |
|------|---------|
| `~/Developer/social-effects/.build/debug/SocialEffects` | Video generation binary |
| `/Volumes/My Passport/social-media-content/social-effects/video/api/` | Generated videos storage |
| `~/Library/Group Containers/group.com.wisdombook.SocialMarketer/` | Core Data, Keychain |

### ⚠️ CRITICAL: Video File Organization Rule

**Social Marketer ONLY reads videos from `video/api/` - NEVER from `video/test/`**

| Folder | Content Type | Should Post? |
|--------|--------------|--------------|
| `video/api/` | Production videos from RSS | ✅ Yes |
| `video/test/` | Test/debug videos | ❌ NEVER |

**Why this matters:** Test videos often have placeholder content like "Test Title" or incomplete quotes. Posting these to social media would be embarrassing and unprofessional.

**Implementation notes:**
- `VideoGenerator.findExistingVideo()` only scans `video/api/` folder
- Test videos with names like `thought-Test_*.mp4` or `thought-Debug_*.mp4` should be ignored
- If a test video is accidentally found in `video/api/`, it should be moved to `video/test/` immediately

## Configuration Files

- **No build-time config** - All settings are runtime configurable
- Platform credentials stored in **macOS Keychain**
- Schedule settings in **UserDefaults**
- Core Data for posts, logs, and cached content

## Testing

### YouTube Test Post

The Test Post button provides a safe way to verify YouTube integration:
- Uses Queue content first, falls back to RSS
- Checks for existing videos before generating
- Logs all steps to ErrorLog
- Only posts to YouTube (not other platforms)

### Health Checks

Dashboard's External Connections panel shows:
- Local Services (Social Effects)
- Content Source (wisdombook.life)
- Social Media APIs
- Search Engines
- RSS Aggregators

## Common Issues

### Social Effects Not Starting

1. Check binary exists at expected path
2. Verify port 5390 not in use: `lsof -i :5390`
3. Check Console.app for startup errors

### YouTube Upload as Private

- API project may need verification in Google Cloud Console
- Check `privacyStatus` is set to "public" in upload request
- Verify `selfDeclaredMadeForKids` is explicitly set

### Video Generation Timeout

- Default timeout: 5 minutes
- Check Social Effects server is responding: `curl http://localhost:5390/health`
- Verify Gemini API key configured in Social Effects

## Code Style

- Use `@MainActor` for UI-updating services
- Prefer `async/await` over completion handlers
- Log all errors to `ErrorLog.shared`
- Use SwiftUI's `@Published` for observable state
- Keep connectors platform-agnostic (no UI code)

## Documentation

- User-facing docs: `/docs/` directory
- Code comments for complex logic
- This AGENTS.md for architectural context

## External Dependencies

- **Social Effects**: Local video generation (separate repo)
- **Platform APIs**: YouTube, Twitter, LinkedIn, etc.
- **RSS Feeds**: wisdombook.life
- **No external Swift packages** - All native frameworks

---

Last Updated: February 21, 2026
