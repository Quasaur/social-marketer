# Social Effects Integration

## Overview

**Social Effects** is a dedicated video rendering engine that generates 15-30 second videos for social media platforms. It operates as a separate application from Social Marketer, handling all video processing independently.

## Architecture

```
Social Marketer (Client)
    ↓ IPC/XPC or File System
Social Effects (Rendering Engine)
    ↓ Uses both rendering engines:
    - AVFoundation (native, 10 effects)
    - MLT Framework (Shotcut, professional effects)
```

## Workflow

### 1. Content Identification

Social Marketer identifies an RSS entry to post to video-compatible platforms:

- YouTube Shorts
- TikTok
- Lemon8
- Other video platforms

### 2. Request Preparation

Social Marketer:

1. Generates unique request ID (`{timestamp}_{uuid}`)
2. Writes request JSON to shared folder:
   - Path: `~/Library/Application Support/SocialEffects/requests/{requestId}.json`
   - Content: RSS data, effect preferences, duration

**Request JSON Format:**

```json
{
  "requestId": "20260214_abc123",
  "rssContent": {
    "title": "True wisdom comes from questions",
    "content": "...",
    "source": "wisdombook.life"
  },
  "effects": {
    "intro": "crossDissolve",
    "ongoing": ["wordReveal", "lightLeaks"],
    "outro": "circularCollapse"
  },
  "duration": 20,
  "platforms": ["youtube", "tiktok"]
}
```

1. Opens URL scheme to trigger Social Effects:
   - `socialeffects://generate?requestId={requestId}`
   - No large data in URL - just the request ID

### 3. Video Generation

Social Effects:

1. Receives URL scheme, launches if needed
2. Reads request JSON from shared folder using `requestId`
3. Generates quote graphic with border style
4. Applies selected effects (intro, ongoing, outro)
5. Renders 15-30 second video (1080x1920 vertical)
6. Saves video to: `~/Library/Application Support/SocialEffects/outputs/{requestId}.mp4`
7. Writes response JSON: `~/Library/Application Support/SocialEffects/responses/{requestId}.json`

**Response JSON Format:**

```json
{
  "requestId": "20260214_abc123",
  "status": "success",
  "videoPath": "~/Library/.../SocialEffects/outputs/20260214_abc123.mp4",
  "duration": 22.5,
  "fileSize": 15728640,
  "format": "mp4",
  "resolution": "1080x1920",
  "effects": ["crossDissolve", "wordReveal", "lightLeaks", "circularCollapse"]
}
```

### 4. Notification

Social Effects posts distributed notification:

- Notification name: `com.quasaur.socialeffects.videoReady`
- User info: `{ "requestId": "20260214_abc123" }`

### 5. Import & Post

Social Marketer:

1. Receives notification via `DistributedNotificationCenter`
2. Reads response JSON from shared folder
3. Imports video from path in response
4. Adds platform-specific metadata (title, description, hashtags)
5. Posts to selected video platforms
6. Cleans up request/response files (optional)

## Communication Method

**URL Scheme + Shared Folder + Distributed Notifications**

**Why this approach:**

- ✅ URL scheme = Simple signaling (no length limits - just IDs)
- ✅ Shared folder = Large data transfer (RSS content, videos)
- ✅ Distributed notifications = Real-time status updates
- ✅ Both apps stay completely independent
- ✅ Easy to debug (inspect files)
- ✅ Resilient (survives app restarts)

**URL Scheme Registration:**
Social Effects registers: `socialeffects://`

**Commands:**

- `socialeffects://generate?requestId={id}` - Generate video
- `socialeffects://status?requestId={id}` - Check status (optional)
- `socialeffects://cancel?requestId={id}` - Cancel generation (optional)

## Video Rendering Engines

### AVFoundation (Native)

**10 Approved Effects:**

- Intros: Cross-Dissolve, Zoom Expand, Wipe, Card Flip H
- Ongoing: Particles, Light Leaks, Word Reveal, Cube Rotate
- Outros: Circular Collapse, Blinds

**Pros:**

- Native macOS, no dependencies
- Fast, lightweight
- Full control

### MLT Framework (Professional)

**Access via Shotcut:**

- Hundreds of professional effects
- Frei0r, OpenCV, Qt6 plugins
- Cinematic transitions

**Pros:**

- Professional quality
- Industry-standard effects

**Cons:**

- Requires C bridging header
- More complex setup

## Effect Selection Strategy

Social Effects will intelligently choose rendering engine:

- **Simple effects**: AVFoundation (fast)
- **Complex/cinematic effects**: MLT (quality)
- **User preference**: Configurable in settings

## File Format

**Output Specifications:**

- Format: MP4 (H.264)
- Resolution: 1080x1920 (vertical)
- Duration: 15-30 seconds
- Framerate: 30fps
- Aspect Ratio: 9:16 (Shorts/TikTok standard)

## Shared Resource Folder Structure

```
~/Library/Application Support/SocialEffects/
├── outputs/
│   ├── {timestamp}_{quote_id}.mp4
│   └── {timestamp}_{quote_id}.json (metadata)
└── cache/
    └── (temporary rendering files)
```

## Error Handling

If Social Effects fails to generate video:

1. Logs error to error file
2. Notifies Social Marketer of failure
3. Social Marketer falls back to static image post

## Future Enhancements

- Real-time preview in Social Marketer
- Effect customization UI
- Batch video generation
- Template library
- Audio/music integration
