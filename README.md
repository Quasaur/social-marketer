# Social Marketer

A native macOS application for automated content distribution from The Book of Wisdom to multiple social media platforms, with integrated video generation via Social Effects.

## Overview

Social Marketer is a Swift/SwiftUI desktop application that automates content syndication from [wisdombook.life](https://wisdombook.life) to social media channels. It features intelligent video generation, queue-based posting, and comprehensive health monitoring.

## Features

### Content Distribution
- **Multi-Platform Posting**: Manage content across 6+ social media platforms (Twitter/X, Instagram, LinkedIn, Facebook, Pinterest, YouTube, TikTok)
- **Post Queue**: Schedule and manage pending posts with drag-and-drop prioritization
- **RSS Integration**: Automatically fetch daily wisdom from wisdombook.life RSS feeds
- **Manual Thought Composition**: Create custom posts with live graphic preview

### Video Generation (Social Effects Integration)
- **Automatic Video Creation**: Converts text wisdom into video Shorts using Social Effects API
- **Video Reuse**: Intelligently checks for existing videos before generating new ones
- **Background Processing**: Videos generate asynchronously while you continue working
- **YouTube Shorts Ready**: Direct upload to YouTube as Shorts with proper metadata
- **TikTok Video Upload**: Post videos directly to TikTok via Content Posting API

### ⚠️ CRITICAL: Video File Organization

**Social Marketer ONLY reads from `video/api/` - test videos go to `video/test/`**

| Folder | Content | Action |
|--------|---------|--------|
| `/social-effects/video/api/` | Production videos | ✅ Scanned and posted |
| `/social-effects/video/test/` | Test/debug videos | ❌ Ignored |

**Important:** If Social Effects accidentally saves test videos (named like `thought-Test_*.mp4`) to `video/api/`, Social Marketer will post them. Always verify test videos are in `video/test/`.

### Platform Configuration
- **OAuth Integration**: Secure credential storage in macOS Keychain
- **Per-Platform Settings**: Enable/disable platforms individually
- **Test Post**: Verify platform connectivity without publishing real content
- **Connection Health Monitoring**: Dashboard shows status of all external services

### Dashboard & Monitoring
- **Real-time Analytics**: Post success rates, platform performance metrics
- **Error Log**: Detailed logging of all operations with category filtering
- **External Connections Panel**: Health status of APIs, RSS feeds, and local services
- **Social Effects Status**: Monitor local video generation service

### Automation
- **Scheduled Posting**: macOS Launch Agent for daily automated posts
- **90-Day Intro Cycle**: Automatically reposts introductory content
- **Queue Processing**: Posts scheduled content when due

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for development)
- Swift 5.9 or later
- [Social Effects](https://github.com/Quasaur/social-effects) (for video generation)

## Project Structure

```
SocialMarketer/
├── Social Marketer/              # Main application
│   ├── App/
│   │   └── SocialMarketerApp.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── DashboardView.swift      # Analytics & health monitoring
│   │   ├── QueueView.swift          # Post queue management
│   │   ├── PlatformSettingsView.swift
│   │   └── ErrorLogView.swift       # Error viewing & filtering
│   ├── Models/
│   │   ├── Post+CoreDataClass.swift
│   │   ├── Platform+CoreDataClass.swift
│   │   └── PostLog+CoreDataClass.swift
│   └── Services/
│       ├── PostScheduler.swift      # Scheduling & automation
│       ├── ConnectionHealthService.swift
│       ├── VideoGenerator.swift     # Social Effects integration
│       └── Connectors/
│           ├── YouTubeConnector.swift
│           ├── TikTokConnector.swift
│           ├── TwitterConnector.swift
│           └── ... (other platforms)
├── docs/
│   ├── platforms/
│   │   └── youtube_testpin_results.md
│   ├── api_dev_portals.md
│   ├── social_effects_integration.md
│   └── ... (other documentation)
└── Social Marketer.xcodeproj
```

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Quasaur/social-marketer.git
cd social-marketer
```

### 2. Setup Social Effects (Required for Video Generation)

Social Marketer requires Social Effects for video generation:

```bash
# Clone Social Effects (in a separate directory)
cd ..
git clone https://github.com/Quasaur/social-effects.git
cd social-effects

# Build the binary
swift build

# Verify the binary exists
ls -la .build/debug/SocialEffects
```

The Social Effects binary must be at:
`/Users/quasaur/Developer/social-effects/.build/debug/SocialEffects`

### 3. Open and Build in Xcode

1. Open `Social Marketer.xcodeproj` in Xcode
2. Select your development team for code signing
3. Build and run (⌘R)

### 4. Initial Configuration

1. **Connect Platforms**: Go to Platform Settings and connect your social media accounts
2. **Configure YouTube**: Requires Google Cloud Console project with YouTube Data API
3. **Test Video Generation**: The app will automatically start Social Effects on launch
4. **Check Dashboard**: Verify all connections show green status

## Usage

### Dashboard

The Dashboard provides an overview of your distribution system:

- **Stats Cards**: Active platforms, posts today, next scheduled post
- **Connection Health**: Real-time status of external services and local Social Effects
- **Analytics**: Success rates by platform and time period
- **Recent Errors**: Detailed log of all operations

### Post Queue

Manage your content pipeline:

- **Pending Posts**: View and manage scheduled content (auto-populated from RSS feeds)
- **Manual Post**: Process the next scheduled post from the queue to all enabled platforms
- **Manual Thought**: Create custom content with graphic preview and add to queue

### Test Posts

All **Test Post** and **Test Pin** buttons use the scheduled post for the day:

1. Go to **Platform Settings**
2. Click **"Test Post"** or **"Test Pin"** next to any platform
3. If the Post Queue is empty, it will **auto-populate from RSS feeds** automatically
4. The scheduled content will be posted **only to the tested platform** (not all platforms)
5. Check **Dashboard → Recent Errors** for any errors

**Key Behaviors:**
- ✅ **Auto-populate**: Empty queue automatically fills from RSS when testing
- ✅ **Single-platform**: Test posts only post to the platform being tested
- ✅ **No fallbacks**: Platforms set to video preference will fail if video generation fails
- ✅ **Safe testing**: Won't trigger posts to all platforms like Manual Post does

### Social Effects Status

Social Effects (video generation) status appears in:

- **Dashboard → External Connections → Local Services**
- **Console logs** on app launch
- **Error Log** if startup fails

## Documentation

| Document | Description |
|----------|-------------|
| [YouTube Test Post Results](docs/platforms/youtube_testpin_results.md) | Debugging YouTube uploads |
| [Social Effects Integration](docs/social_effects_integration.md) | Video generation setup |
| [API Developer Portals](docs/api_dev_portals.md) | Getting API keys for each platform |
| [Marketing Strategy](docs/marketing_strategy.md) | Content distribution strategy |

## Troubleshooting

### Social Effects Won't Start

1. Verify binary exists: `ls ~/.build/debug/SocialEffects`
2. Check Console.app for error messages
3. Try manual start: `./social-effects/.build/debug/SocialEffects api-server`

### YouTube Upload Fails

1. Check Dashboard → Recent Errors for details
2. Verify API project has YouTube Data API enabled
3. Check OAuth consent screen includes `youtube.upload` scope
4. See [YouTube Test Post Results](docs/platforms/youtube_testpin_results.md)

### TikTok Connection Issues

1. Check that your TikTok Developer app is approved for **Content Posting API**
2. Verify DNS TXT record is properly added to your domain (see [API Developer Portals](docs/api_dev_portals.md))
3. Ensure redirect URI is set to: `http://localhost:9095/oauth/callback`
4. Check that media preference is set to **Video** (image posts not yet supported)

### Video Generation Timeout

1. Check Social Effects is running (Dashboard → External Connections)
2. Verify Gemini API key is set (in Social Effects .env file)
3. Check available disk space

## License

MIT License - See LICENSE file

## Contact

For questions or support: <devcalvinlm@gmail.com>

---

**Note**: This is an active development project. Features and APIs may change.
