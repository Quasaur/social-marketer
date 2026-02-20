# Social Effects Integration Guide

## Overview

Social Marketer integrates with Social Effects via HTTP API to generate professional videos from RSS content.

## Prerequisites

1. Social Effects must be installed and built:
   ```bash
   cd /Users/quasaur/Developer/social-effects
   swift build
   ```

2. Environment variables configured in Social Effects:
   - `GEMINI_API_KEY` (for background generation, optional)
   - `FAL_KEY` (for Pika backgrounds, optional)

## API Server Configuration

**Host:** localhost  
**Port:** 5390 (default)

The Social Effects API server must be running before Social Marketer can request video generation.

## Starting the Integration

### 1. Start Social Effects API Server

```bash
cd /Users/quasaur/Developer/social-effects
swift run SocialEffects api-server
```

The server will listen on port 5390 by default.

### 2. Health Check

Before generating videos, verify the server is ready:

```bash
curl http://localhost:5390/health
```

Expected response:
```json
{"status":"ok"}
```

## Video Generation Flow

### Step 1: Select RSS Item

Social Marketer selects the RSS item to publish from wisdombook.life feeds.

### Step 2: Request Video Generation

Send a POST request to generate the video:

```bash
curl -X POST http://localhost:5390/generate \
  -H "Content-Type: application/json" \
  -d '{
    "title": "THE ULTIMATE",
    "content": "That which is Ultimate cannot be Ultimate unless \"it\" (He) is also PERSONAL.",
    "ping_pong": true
  }'
```

### Step 3: Handle Response

**Success Response:**
```json
{
  "success": true,
  "video_path": "/Volumes/My Passport/social-media-content/social-effects/video/api/video_1234567890.mp4"
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Missing title or content"
}
```

### Step 4: Use Generated Video

The video is ready at the returned `video_path`. Social Marketer can now:
- Upload to social media platforms
- Schedule posts
- Archive for future use

## API Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `title` | string | Yes | Video title (usually RSS item title) |
| `content` | string | Yes | Quote/text content (RSS item content) |
| `ping_pong` | boolean | No | Enable ping-pong background effect (default: false) |

## Video Output Location

All generated videos are saved to:
```
/Volumes/My Passport/social-media-content/social-effects/video/api/
```

## Timing Reference

Generated videos follow this cinematic timeline:
- **0-3s:** Black screen
- **3-7s:** Background fades in
- **7-9s:** Text overlay fades in
- **9s:** Narration starts (text fully visible)
- **End:** CTA outro with background music

## Implementation Example (Swift)

```swift
import Foundation

class SocialEffectsClient {
    let baseURL = "http://localhost:5390"
    
    func generateVideo(title: String, content: String, pingPong: Bool = true) async throws -> String {
        let url = URL(string: "\(baseURL)/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "title": title,
            "content": content,
            "ping_pong": pingPong
        ] as [String : Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let success = json?["success"] as? Bool, success,
              let path = json?["video_path"] as? String else {
            throw NSError(domain: "SocialEffects", code: 1, userInfo: [NSLocalizedDescriptionKey: json?["error"] as? String ?? "Unknown error"])
        }
        
        return path
    }
    
    func healthCheck() async throws -> Bool {
        let url = URL(string: "\(baseURL)/health")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
        return json?["status"] == "ok"
    }
}
```

## Troubleshooting

### Connection Refused
- Ensure Social Effects API server is running
- Verify port 5390 is not blocked
- Check that the server started successfully

### Video Generation Fails
- Check Social Effects logs for FFmpeg errors
- Verify disk space on `/Volumes/My Passport/`
- Ensure audio cache directory is writable

### Timeout Issues
- Video generation takes 10-30 seconds depending on content
- Implement appropriate timeout handling (recommend 60s timeout)

## Port Configuration

If you need to use a different port:

1. Start Social Effects with custom port:
   ```bash
   swift run SocialEffects api-server 9090
   ```

2. Update Social Marketer to use the new port:
   ```swift
   let baseURL = "http://localhost:9090"
   ```

## Security Notes

- The API server currently binds to localhost only
- No authentication is implemented (trusted local environment)
- For production use, consider adding API key authentication
