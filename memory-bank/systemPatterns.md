# System Patterns: Social Marketer

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Social Marketer                           │
│                    (macOS Swift/SwiftUI App)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │   RSS Parser │───▶│ Quote Graphic│───▶│ Platform Router  │  │
│  │              │    │ Generator    │    │                  │  │
│  └──────────────┘    └──────────────┘    └────────┬─────────┘  │
│         │                                         │             │
│         │                                         ▼             │
│         │                              ┌──────────────────┐     │
│         │                              │ Platform Connect │     │
│         │                              │ ├─ Twitter       │     │
│         │                              │ ├─ Instagram     │     │
│         │                              │ ├─ LinkedIn      │     │
│         │                              │ ├─ YouTube       │     │
│         │                              │ └─ Substack      │     │
│         │                              └──────────────────┘     │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────┐    ┌──────────────────┐                       │
│  │  Core Data   │    │ Social Effects   │                       │
│  │  Persistence │    │ HTTP API         │                       │
│  └──────────────┘    └──────────────────┘                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Key Patterns

### 1. Service Layer Pattern
All external interactions encapsulated in services:
- **RSSParser**: Fetches and parses wisdombook.life feeds
- **QuoteGraphicGenerator**: Renders quote graphics using Core Graphics
- **PlatformRouter**: Routes content to appropriate connectors
- **PostScheduler**: Manages timing and frequency

### 2. Platform Connector Protocol
```swift
protocol PlatformConnector {
    var name: String { get }
    var isEnabled: Bool { get set }
    
    func authenticate() async throws
    func post(content: PostContent) async throws
    func validateCredentials() async -> Bool
}
```

### 3. Content Pipeline
```
RSS Item → Content Model → Graphic Generation → Platform Distribution
                ↓
         Core Data Persistence
```

### 4. Background Execution (launchd)
- Agent runs as user daemon
- Executes posting schedule
- Logs results for UI display

### 5. Image Generation Strategy
- 10 bundled border templates (PNG assets)
- Core Graphics text overlay
- Dynamic sizing for platform requirements
- Watermarked output
- **Shared drawing helpers** (e.g., `fillCircle()`) for consistent rendering

## Data Flow

### Post Creation Flow
1. RSS Parser fetches new content
2. Content stored in Core Data
3. QuoteGraphicGenerator creates image
4. User reviews in UI
5. PlatformRouter distributes to enabled platforms
6. Results logged to PostLog

### Background Execution Flow
1. launchd triggers at scheduled time
2. Fetches pending posts from Core Data
3. For each post:
   - Generate/update graphic
   - Distribute to platforms
   - Log results
4. Complete cycle

## Design Decisions

### Why Native macOS?
- Full access to system capabilities
- No browser automation limitations
- Better performance for image generation
- Native SwiftUI integration

### Why Core Graphics over External AI?
- No API costs
- No network dependency for rendering
- Faster generation
- Privacy (no data sent to external services)

### Why launchd over Cron?
- Native macOS solution
- Better system integration
- Proper logging via os_log
- User context execution

## Integration Points

### Social Effects
- HTTP API on localhost:5390
- POST /generate for video creation
- Video stored on external drive
- Social Marketer retrieves path and uploads

### wisdombook.life
- RSS feeds provide content
- Multiple feed types (daily, thoughts, quotes, passages)
- XML parsing with RSSParser service

### Platform APIs
- OAuth 1.0a (Twitter, etc.)
- OAuth 2.0 (LinkedIn, etc.)
- Basic Auth + cookies (Substack)
