# IG Reel Upload API Request 
## Q:
Where can I find Instagram's API request format for uploading a reel?

## A:
To upload an Instagram Reel via the API, you use the Instagram Graph API (part of the Facebook Graph API). The process is a two-step "asynchronous" flow: first, you create a media container, and then you publish it.
Since the Instagram Basic Display API was fully retired at the end of 2024, you must use a Business or Creator account and have the instagram_content_publish permission.
Step 1: Create a Reels Container
Send a POST request to the media endpoint. This doesn't post the Reel yet; it tells Instagram where to fetch your video file.
Endpoint:
POST https://graph.facebook.com/v25.0/{ig-user-id}/media
Request Body (JSON):

```json

{
  "media_type": "REELS",
  "video_url": "https://yourserver.com/video.mp4",
  "caption": "Check out my new Reel! #coding #api",
  "share_to_feed": true, 
  "access_token": "{your-access-token}"
}
```

 * share_to_feed: Set to true if you want the Reel to also appear on your main Profile Grid.
 * Response: You will receive a creation_id (e.g., 17841405303065173).
Step 2: Publish the Container
Once the video is processed (you can check status via the creation_id), you must finalize the post.
Endpoint:
POST https://graph.facebook.com/v25.0/{ig-user-id}/media_publish
Request Body (JSON):

```json

{
  "creation_id": "{creation-id-from-step-1}",
  "access_token": "{your-access-token}"
}
```


Technical Specifications for Reels
To avoid the common "Unsupported post request" error, ensure your video meets these 2026 requirements:
| Requirement | Specification |
|---|---|
| Container | MP4 or MOV |
| Video Codec | H.264 or HEVC |
| Aspect Ratio | 9:16 (Recommended) |
| Resolution | 1080 x 1920 pixels |
| Duration | 3 seconds to 15 minutes |
| File Size | 100MB max (suggested) |
Pro Tips:
 * Hosting: The video_url must be a public, direct link to the file. Instagram's servers need to reach it.
 * Status Check: If Step 2 fails immediately, it's usually because the video is still processing. You can GET /{creation_id}?fields=status_code to wait for the FINISHED status.
Would you like me to generate a Python or Node.js script to automate this entire two-step process for you?

## Q:
Give me a swift file.

## A:
Since you're likely building for iOS or a server-side Swift environment, I’ve put together a clean, modern implementation using async/await and URLSession.
This script handles the two-step dance: creating the container and then publishing it.

### InstagramReelUploader.swift
```swift

import Foundation

struct ReelUploader {
    let accessToken: String
    let instagramID: String
    let apiVersion = "v25.0"
    
    enum UploadError: Error {
        case invalidURL
        case noData
        case decodingError
    }

    /// Uploads a reel from a public URL
    func uploadReel(videoUrl: String, caption: String) async throws -> String {
        // Step 1: Create the Media Container
        let creationID = try await createContainer(videoUrl: videoUrl, caption: caption)
        
        // Wait briefly for Instagram to process the video
        // In production, you'd ideally poll the status_code endpoint
        try await Task.sleep(nanoseconds: 5_000_000_000) 
        
        // Step 2: Publish the Container
        return try await publishContainer(creationID: creationID)
    }

    private func createContainer(videoUrl: String, caption: String) async throws -> String {
        let urlString = "https://graph.facebook.com/\(apiVersion)/\(instagramID)/media"
        guard let url = URL(string: urlString) else { throw UploadError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "media_type": "REELS",
            "video_url": videoUrl,
            "caption": caption,
            "share_to_feed": true,
            "access_token": accessToken
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let id = json?["id"] as? String else { throw UploadError.decodingError }
        return id
    }

    private func publishContainer(creationID: String) async throws -> String {
        let urlString = "https://graph.facebook.com/\(apiVersion)/\(instagramID)/media_publish"
        guard let url = URL(string: urlString) else { throw UploadError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "creation_id": creationID,
            "access_token": accessToken
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let postID = json?["id"] as? String else { throw UploadError.decodingError }
        return postID
    }
}
```


Implementation Details
 * Permissions: Ensure your access token has instagram_basic and instagram_content_publish.
 * Video Hosting: The videoUrl must be a direct link (ending in .mp4 or similar) that is publicly accessible. Local file paths will not work; you must upload the file to a CDN or S3 bucket first.
 * Error Handling: I've used a simple JSONSerialization approach, but for a production app, you might want to define Codable structs for the response.
How to use it:

```swift

let uploader = ReelUploader(accessToken: "YOUR_TOKEN", instagramID: "YOUR_ID")

Task {
    do {
        let finalID = try await uploader.uploadReel(
            videoUrl: "https://example.com/my-video.mp4", 
            caption: "Hello from Swift!"
        )
        print("Success! Reel ID: \(finalID)")
    } catch {
        print("Upload failed: \(error)")
    }
}
```


Would you like me to add a status check function to this file so you can verify the video is finished processing before hitting the publish endpoint?

## Q:
Yes.

## A:
Adding a status check is highly recommended because Instagram's video processing time varies based on file size and server load. If you try to publish before the status is FINISHED, the API will return a 400 Bad Request.
Here is the updated Swift file with a polling mechanism to ensure the video is ready before the final publish call.
### InstagramReelUploader.swift (Enhanced)
```swift

import Foundation

struct ReelUploader {
    let accessToken: String
    let instagramID: String
    let apiVersion = "v25.0"
    
    enum UploadError: Error {
        case invalidURL
        case noData
        case decodingError
        case processingFailed(String)
        case timeout
    }

    /// Complete flow: Create -> Wait for Processing -> Publish
    func uploadReel(videoUrl: String, caption: String) async throws -> String {
        // 1. Create Container
        let creationID = try await createContainer(videoUrl: videoUrl, caption: caption)
        print("Container created: \(creationID). Waiting for processing...")
        
        // 2. Poll for Status (Max 10 attempts, 5 seconds apart)
        try await waitForProcessing(creationID: creationID)
        
        // 3. Publish
        print("Processing finished. Publishing...")
        return try await publishContainer(creationID: creationID)
    }

    private func createContainer(videoUrl: String, caption: String) async throws -> String {
        let urlString = "https://graph.facebook.com/\(apiVersion)/\(instagramID)/media"
        let body: [String: Any] = [
            "media_type": "REELS",
            "video_url": videoUrl,
            "caption": caption,
            "share_to_feed": true,
            "access_token": accessToken
        ]
        return try await performPost(urlString: urlString, body: body)
    }

    private func waitForProcessing(creationID: String) async throws {
        let urlString = "https://graph.facebook.com/\(apiVersion)/\(creationID)?fields=status_code&access_token=\(accessToken)"
        
        for _ in 1...10 {
            guard let url = URL(string: urlString) else { throw UploadError.invalidURL }
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let status = json?["status_code"] as? String {
                if status == "FINISHED" { return }
                if status == "ERROR" { throw UploadError.processingFailed("Instagram processing error") }
            }
            
            // Wait 5 seconds before checking again
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }
        throw UploadError.timeout
    }

    private func publishContainer(creationID: String) async throws -> String {
        let urlString = "https://graph.facebook.com/\(apiVersion)/\(instagramID)/media_publish"
        let body: [String: Any] = [
            "creation_id": creationID,
            "access_token": accessToken
        ]
        return try await performPost(urlString: urlString, body: body)
    }

    // Helper for POST requests
    private func performPost(urlString: String, body: [String: Any]) async throws -> String {
        guard let url = URL(string: urlString) else { throw UploadError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let id = json?["id"] as? String else { 
            print("API Error: \(String(describing: json))")
            throw UploadError.decodingError 
        }
        return id
    }
}
```


How this Flow Works
The polling logic follows the official Graph API requirements for media publishing.
Key Improvements:
 * Polling Loop: Instead of a hard-coded "sleep," it checks the status_code every 5 seconds. This makes your app faster if the video processes quickly, and safer if it takes longer.
 * Error Handling: If Instagram's internal transcoder fails (usually due to an unsupported codec), the status_code will return ERROR, and the Swift code will catch it.
 * Timeout: It will try for up to 50 seconds (10 attempts) before giving up, preventing your app from being stuck in an infinite loop.
One Final Tip:
Make sure your App Dashboard in the Meta for Developers portal has the Instagram Graph API product added and your app is in "Live" mode if you're planning to let other users upload via your app.
Do you need help setting up the Privacy Policy or Data Deletion URLs required by Meta to take this app live?

## Q:
Yes for the Data Deletion URL.

## A:
Setting up the Data Deletion and Privacy Policy URLs is a non-negotiable step to move your App from "Development" to "Live" mode in the Meta App Dashboard. Meta requires these to ensure users have a way to request that their data (like their Instagram ID or Access Token) be removed from your database.
1. The Data Deletion Callback URL
Meta gives you two options for handling data deletion. The Callback URL is the most professional approach because it automates the process.
How the Callback Works:
When a user removes your app via their Facebook/Instagram settings, Meta sends a POST request to your URL containing a signed_request.
The Swift (Server-side) Logic:
If you are using Vapor or another Swift server framework, your endpoint needs to:
 * Parse the signed_request.
 * Decode the Base64 URL-encoded JSON.
 * Verify the signature using your App Secret.
 * Delete the user's data from your database.
 * Return a JSON response with a confirmation code and a status URL.
2. The Data Deletion Instructions URL
If you don't have a backend set up to handle real-time callbacks yet, you can provide a Data Deletion Instructions URL. This is simply a static webpage on your site that tells the user:
 * What data you collect.
 * How they can contact you to request deletion (e.g., an email address).
 * The steps they need to take to remove the app.
3. Where to Add These in the Meta Dashboard
 * Go to the Meta for Developers portal.
 * Select your App.
 * Navigate to Settings > Basic.
 * Scroll down to the Privacy Policy URL and User Data Deletion fields.
4. Privacy Policy Requirements
For an Instagram-connected app, your Privacy Policy must explicitly state:
 * Permissions used: Mention you access instagram_basic and instagram_content_publish.
 * Third-party sharing: State that you do not sell their Instagram content.
 * Retention: How long you keep their Access Tokens.
> Pro Tip: If you use a static site generator (like Jekyll or Hugo) or even a GitHub README rendered as a page, those work perfectly fine as valid URLs for Meta's verification team.
> 
Would you like a Swift/Vapor code snippet to help you decode that signed_request for the automated callback?

## Q:
Yes.

## A:
To handle the Data Deletion Callback in Swift (specifically using the Vapor framework), you need to decode a signed_request. This is a string sent by Meta that is split into two parts by a dot: a signature and a payload.
Here is a robust implementation to handle the verification and decoding.
DataDeletionController.swift
```swift
import Vapor
import Crypto

struct DataDeletionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("instagram", "deauthorize", use: handleDeletion)
    }

    func handleDeletion(req: Request) async throws -> Response {
        // 1. Get the signed_request from the POST body
        // Meta sends this as application/x-www-form-urlencoded
        struct MetaRequest: Content {
            let signed_request: String
        }
        let body = try req.content.decode(MetaRequest.self)
        
        // 2. Split the signed_request
        let parts = body.signed_request.components(separatedBy: ".")
        guard parts.count == 2 else { throw Abort(.badRequest) }
        
        let encodedSig = parts[0]
        let payload = parts[1]
        
        // 3. Verify the signature using your App Secret
        let appSecret = "YOUR_APP_SECRET" // Get this from Meta Dashboard
        let hmac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: SymmetricKey(data: Data(appSecret.utf8)))
        
        // Convert HMAC to Base64URL to compare with encodedSig
        let digestBase64 = Data(hmac).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        guard digestBase64 == encodedSig else {
            throw Abort(.unauthorized, reason: "Invalid Signature")
        }

        // 4. Decode the Payload
        guard let decodedData = dataFromBase64URL(payload),
              let json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any],
              let userID = json["user_id"] as? String else {
            throw Abort(.badRequest)
        }

        // 5. Execute Deletion Logic
        print("Deleting data for Instagram User: \(userID)")
        // try await User.query(on: req.db).filter(\.$instagramID == userID).delete()

        // 6. Return the required confirmation JSON
        let response: [String: String] = [
            "url": "https://yourdomain.com/deletion-status?id=\(userID)",
            "confirmation_code": "del_\(userID)_\(Date().timeIntervalSince1970)"
        ]
        
        return try await response.encodeResponse(for: req)
    }

    private func dataFromBase64URL(_ base64URL: String) -> Data? {
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        return Data(base64Encoded: base64)
    }
}
```

Why this logic is required
Meta uses the signed_request to prevent "spoofing." If you didn't verify the signature with your App Secret, anyone could hit your deletion endpoint and delete your users' data just by knowing their Instagram ID.
Key Requirements for the Response:
Meta expects exactly two fields in your JSON response:
 * url: A link where the user can check the status of their deletion request (a simple "Data Deleted" static page is usually fine).
 * confirmation_code: A unique string you generate for tracking the request.
Dashboard Setup
Once your code is deployed:
 * Copy the URL (e.g., https://api.yourdomain.com/instagram/deauthorize).
 * Go to App Settings > Basic in the Meta Dashboard.
 * Paste it into the Data Deletion Callback URL field.
 * Click "Check URL"—Meta will send a test request to your server. If your code returns the JSON correctly, it will be verified.
Would you like me to create a simple Privacy Policy template that you can host on your site to pass Meta's app review?
