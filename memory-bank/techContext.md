# Technical Context: Social Marketer

## Technology Stack

### Core Technologies
| Component | Technology | Version |
|-----------|-----------|---------|
| Language | Swift | 5.9+ |
| Framework | SwiftUI | macOS 14.0+ |
| Persistence | Core Data | Native |
| Reactive | Combine | Native |
| Networking | URLSession | Native |
| Security | Keychain Services | Native |

### Build Requirements
- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **Target**: macOS 14.0+

## Project Structure

```
SocialMarketer/
├── App/
│   └── SocialMarketerApp.swift    # App entry point
├── Views/
│   ├── ContentView.swift          # Main tab view
│   ├── DashboardView.swift        # Overview and status
│   ├── ComposeThoughtView.swift   # Manual post creation
│   ├── QueueView.swift            # Pending posts queue
│   ├── SettingsView.swift         # App configuration
│   └── PlatformSettingsView.swift # Platform credentials
├── Models/
│   ├── SocialMarketer.xcdatamodeld # Core Data schema
│   ├── Post+CoreDataClass.swift   # Post entity
│   ├── Platform+CoreDataClass.swift # Platform entity
│   └── PostLog+CoreDataClass.swift # Log entity
├── Services/
│   ├── RSSParser.swift            # RSS feed parsing
│   ├── QuoteGraphicGenerator.swift # Image generation
│   ├── PlatformRouter.swift       # Content distribution
│   ├── PostScheduler.swift        # Scheduling logic
│   ├── KeychainService.swift      # Credential storage
│   └── Connectors/                # Platform implementations
│       ├── PlatformConnectorProtocol.swift
│       ├── TwitterConnector.swift
│       ├── InstagramConnector.swift
│       ├── LinkedInConnector.swift
│       ├── YouTubeConnector.swift
│       └── SubstackConnector.swift
└── Resources/
    ├── Borders/                   # 10 border templates
    └── com.wisdombook.SocialMarketer.plist
```

## Dependencies

### External Dependencies
None required for V1 - all functionality uses native macOS frameworks.

### System Frameworks Used
- **SwiftUI**: UI layer
- **Core Data**: Persistence
- **Combine**: Reactive programming
- **Core Graphics**: Image generation
- **Security/Keychain**: Credential storage
- **Foundation**: Networking, XML parsing

## External Services

### Content Source
- **wisdombook.life**: RSS feeds
- **Feeds**: daily.xml, thoughts.xml, quotes.xml, passages.xml
- **Protocol**: HTTPS + RSS 2.0

### Social Media APIs
| Platform | API Version | Auth Method |
|----------|-------------|-------------|
| X (Twitter) | API v2 | OAuth 1.0a |
| Instagram | Graph API | OAuth 2.0 |
| LinkedIn | REST API | OAuth 2.0 |
| YouTube | Data API v3 | OAuth 2.0 |
| Substack | Web API | Cookie-based |

### Video Generation
- **Social Effects**: HTTP API on localhost:5390
- **Endpoint**: POST /generate
- **Transport**: HTTP/REST + JSON
- **Storage**: External drive (shared path)

### Search/Distribution
- **Google Search Console**: Indexing API
- **Feedly**: RSS submission

## Configuration

### App Configuration
Stored in `com.wisdombook.SocialMarketer.plist`:
- RSS feed URLs
- Posting schedules
- Platform enable/disable flags
- Social Effects API endpoint

### Sensitive Data
Stored in Keychain:
- OAuth tokens
- API keys
- Platform credentials

## Development Environment

### Required Setup
1. macOS 14.0+ development machine
2. Xcode 15.0+
3. Apple Developer account (for signing)
4. External drive mounted at `/Volumes/My Passport/`

### Testing Requirements
- Test accounts on all 5 platforms
- Sandbox credentials where available
- Test RSS feed endpoint

## Deployment

### Distribution
- Mac App Store (future)
- Direct distribution (.dmg)
- Notarized app bundle

### Background Service
- launchd plist installed to `~/Library/LaunchAgents/`
- Runs as user agent (not root)
- Logs to Console app via os_log

## Performance Considerations

### Image Generation
- Core Graphics: ~100-200ms per image
- Templates cached in memory
- Async generation to prevent UI blocking

### Network Operations
- URLSession with background configuration
- Retry logic for failed posts
- Exponential backoff for rate limits

### Storage
- Core Data with WAL mode for performance
- Images stored on external drive
- Log rotation to prevent bloat
