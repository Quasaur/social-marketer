# How to View YouTube Test Post Results

This guide explains how to view the results and logs from the YouTube "Test Post" button in Social Marketer.

---

## Overview

The YouTube "Test Post" button (located in **Platforms → YouTube**) allows you to test uploading a video to YouTube without running a full scheduled post. This is useful for:

- Verifying YouTube API credentials are working
- Testing video generation/upload flow
- Debugging upload issues before they affect scheduled posts

---

## Option 1: In-App Error Log (Easiest) ✅

The YouTube Test Post logs everything to Social Marketer's built-in Error Log system.

### Where to Find It

1. Open **Social Marketer**
2. Click the **"Dashboard"** tab at the top
3. Scroll down to the **"Recent Errors"** section (bottom of page)

### Understanding the Log Entries

| Badge | Log Entry | Meaning |
|-------|-----------|---------|
| 🟦 | **YouTube** - "Test Post started" | Button was clicked |
| 🟦 | **YouTube** - "Using queued post: [title]" | Found content in Queue |
| 🟦 | **YouTube** - "Using RSS feed: [title]" | Fetched from RSS (queue empty) |
| 🟦 | **YouTube** - "Using existing video" | Found matching video file |
| 🟦 | **YouTube** - "Generating new video" | Creating new video (takes time) |
| 🟦 | **YouTube** - "Video generated successfully" | Video ready |
| 🟦 | **YouTube** - "Uploading to YouTube" | Upload in progress |
| 🟩 | **YouTube** - "Posted to YouTube! 🎬" | **SUCCESS!** Shows URL |
| 🟥 | **YouTube** - "YouTube upload failed" | Failed - click to expand details |

### Managing the Error Log

- **Expand details:** Click the chevron (▼) next to any entry with details
- **Clear old errors:** Click **"Clear All"** button in the top-right of the Recent Errors section
- **Maximum entries:** The log keeps the 100 most recent entries

---

## Option 2: Xcode Console (For Deep Debugging)

If you need more technical details while running from Xcode:

### Show the Debug Area

1. In Xcode, ensure the **Debug Area** is visible:
   - Menu: **View → Debug Area → Show Debug Area** (or press `Cmd+Shift+Y`)

2. Run the app and click **"Test Post"**

3. Watch the console for detailed logs:
   ```
   📝 Using QUEUED post: [title]
   🎬 Using existing video: thought-Direct_Binary-1771607724.mp4
   📤 Uploading to YouTube: [title]
   ✅ YouTube upload complete: https://youtube.com/shorts/xxxxx
   ```

4. **Look for errors** in red text if something fails

### Common Console Messages

```
✅ Found existing video: thought-[Title]-[timestamp].mp4
🎬 Using existing video for: [Title]
🎬 No existing video found, generating new video for: [Title]
📤 Uploading to YouTube: [Title]
✅ Posted to YouTube! 🎬
```

---

## Option 3: macOS Console App (System-Level)

For viewing all app logs, including those from crashes or background execution:

### Steps

1. Open **Console.app** (located in Applications/Utilities)
2. In the search bar, type: `SocialMarketer`
3. Click the **"Start"** button (or press `Cmd+R`) to stream logs
4. Run the Test Post in Social Marketer
5. Logs appear in real-time with timestamps

### Filtering Tips

- Search for `[YouTube]` to see only YouTube-related logs
- Search for `Error` to find error messages
- Use the timestamp column to correlate with when you clicked the button

---

## Understanding Test Post Results

### Success Scenario

```
📝 Using QUEUED post: Direct Binary
🎬 Using existing video: thought-Direct_Binary-1771607724.mp4
📤 Uploading to YouTube: Direct Binary
✅ Posted to YouTube! 🎬
URL: https://www.youtube.com/shorts/AbCdEfGhIjK
Post ID: AbCdEfGhIjK
```

**Next Steps:**
- Video should appear in YouTube Studio
- Check if it's **Public** (should be with new metadata fixes)
- If it's **Private**, your API project may need verification

### Common Failure Scenarios

#### 1. "YouTube not configured"

**Cause:** OAuth tokens missing or expired  
**Fix:** Disconnect and reconnect YouTube in Platform Settings

#### 2. "No posts in queue and RSS feed unavailable"

**Cause:** Queue is empty AND RSS feed can't be reached  
**Fix:** Check internet connection or add items to Queue

#### 3. "Video generation failed"

**Cause:** Social Effects server not running or error in generation  
**Fix:** Check if Social Effects API is accessible at `http://localhost:5390`

#### 4. Upload succeeds but video is PRIVATE

**Cause:** Google Cloud API project not verified  
**Fix:** See [YouTube API Project Verification](../api_dev_portals.md#youtube)

#### 5. Upload fails with 403 error

**Cause:** Insufficient OAuth scopes or API project restrictions  
**Fix:** Check OAuth consent screen has `youtube.upload` scope

---

## What the Test Post Does

1. **Gets Content**
   - First pending post from Queue, OR
   - Daily wisdom from RSS feed

2. **Finds/Generates Video**
   - Checks `/Volumes/My Passport/social-media-content/social-effects/video/api/`
   - Uses existing video if title matches
   - Generates new video if not found

3. **Uploads to YouTube**
   - Sets all required metadata:
     - `selfDeclaredMadeForKids: false`
     - `categoryId: 27` (Education)
     - `containsSyntheticMedia: false`
     - `privacyStatus: public`
   - Uploads video only (no other platforms)

4. **Updates Queue**
   - Marks queued post as posted (if from queue)
   - Creates PostLog entry for tracking

---

## Related Documentation

- [YouTube Connector Implementation](../../../Social%20Marketer/Social%20Marketer/Services/Connectors/YouTubeConnector.swift)
- [Social Effects Integration](../social_effects_integration.md)
- [API Developer Portals](../api_dev_portals.md)
- [Error Log Service](../../../Social%20Marketer/Social%20Marketer/Services/ErrorLogService.swift)

---

*Last Updated: February 20, 2026*
