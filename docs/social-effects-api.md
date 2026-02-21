# Social-Effects API Integration

**For**: Social-Marketer Desktop App  
**API Server**: Social-Effects CLI (`api-server` command)  
**Port**: 5390 (default)  
**Date**: Created from social-effects workspace

---

## API Endpoints

### POST /generate

Generates a video short from text content.

#### Request Format

```json
{
  "title": "Video Title",
  "content": "Quote or wisdom text content",
  "content_type": "thought|quote|passage",
  "node_title": "Node_Title_From_RSS",
  "ping_pong": false
}
```

#### Request Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Video title (displayed in graphic) |
| `content` | string | Yes | Quote or wisdom text for TTS narration |
| `content_type` | string | Yes | Type of content: "thought", "quote", or "passage" |
| `node_title` | string | Yes | Node name from wisdombook.life RSS (used in filename) |
| `ping_pong` | boolean | No | Enable ping-pong background looping (default: false) |

#### Response Format (Success)

```json
{
  "success": true,
  "video_path": "/Volumes/.../thought-Node_Title-1234567890.mp4"
}
```

#### Response Format (Error)

```json
{
  "success": false,
  "error": "Error description"
}
```

---

### POST /shutdown

Gracefully shuts down the social-effects API server.

#### Request

```bash
POST http://localhost:5390/shutdown
```

#### Response Format (Success)

```json
{
  "status": "shutting_down"
}
```

**Note:** After receiving the response, the server will stop accepting new connections and shut down within 1 second.

---

### GET /health

Health check endpoint.

#### Response

```json
{
  "status": "ok"
}
```

---

## Filename Format

Generated videos follow this naming convention:

```
<content-type>-<Node_Title>-<timestamp>.mp4
```

**Examples:**
- `thought-Wisdom_Questions-1739999999.mp4`
- `quote-Marcus_Aurelius-1739999999.mp4`
- `passage-Daily_Wisdom-1739999999.mp4`

---

## Sample Swift Code for Social-Marketer

```swift
struct VideoRequest: Codable {
    let title: String
    let content: String
    let content_type: String
    let node_title: String
    let ping_pong: Bool?
}

struct VideoResponse: Codable {
    let success: Bool
    let video_path: String?
    let error: String?
}

func generateVideo(title: String, content: String, contentType: String, nodeTitle: String) async throws -> String {
    let url = URL(string: "http://localhost:5390/generate")!
    let request = VideoRequest(
        title: title,
        content: content,
        content_type: contentType,
        node_title: nodeTitle,
        ping_pong: false
    )
    
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)
    
    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    let videoResponse = try JSONDecoder().decode(VideoResponse.self, from: data)
    
    guard videoResponse.success, let path = videoResponse.video_path else {
        throw NSError(domain: "VideoGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: videoResponse.error ?? "Unknown error"])
    }
    
    return path
}
```

---

## Notes for Social-Marketer Integration

1. **RSS Source**: Social-marketer should fetch content from wisdombook.life RSS feeds (daily, thoughts, quotes, passages)

2. **Content Mapping**:
   - RSS item title → `title` field
   - RSS item content → `content` field
   - RSS node/taxonomy → `content_type` field
   - RSS node name → `node_title` field

3. **Output Location**: Videos are saved to `/Volumes/My Passport/social-media-content/social-effects/video/`

   ### ⚠️ CRITICAL: Video Folder Structure
   
   ```
   video/
   ├── api/    # ⚠️ PRODUCTION VIDEOS ONLY - Social Marketer posts these
   └── test/   # ⚠️ TEST VIDEOS - Social Marketer ignores these
   ```
   
   **Rule:** Test videos (names containing `Test`, `Debug`, etc.) must NEVER be saved to `video/api/`. Social Marketer scans this folder and will post any video it finds.

4. **Error Handling**: API returns HTTP 200 for successful requests (even if video generation fails internally). Check `success` field in response.

5. **Server Start**: Ensure social-effects API server is running:
   ```bash
   cd /Users/quasaur/Developer/social-effects
   swift run SocialEffects api-server
   ```
