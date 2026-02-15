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

### 2. Send to Social Effects

Social Marketer sends either:

- **RSS link**, or
- **RSS content** (title, body, source)

to Social Effects for video creation.

**Communication Method**: TBD (options: XPC service, URL scheme, file drop)

### 3. Video Generation

Social Effects:

- Parses RSS content
- Generates quote graphic with border style
- Applies selected effects (intro, ongoing, outro)
- Renders 15-30 second video (1080x1920 vertical)
- Saves to shared resource folder

**Shared Resource Folder**: `~/Library/Application Support/SocialEffects/outputs/`

### 4. Notification

Social Effects notifies Social Marketer:

- Video path
- Video metadata (duration, size, format)
- Generation status (success/failure)

**Notification Method**: TBD (options: XPC callback, file system watcher, URL callback)

### 5. Import & Post

Social Marketer:

- Imports video from shared path
- Adds platform-specific metadata (title, description, hashtags)
- Posts to selected video platforms
- Cleans up temporary video file (optional)

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
