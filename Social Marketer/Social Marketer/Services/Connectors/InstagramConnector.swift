//
//  InstagramConnector.swift
//  SocialMarketer
//
//  Created by Automation on 2026-02-16.
//

import Foundation
import AppKit

// MARK: - Instagram Connector

final class InstagramConnector: VideoPlatformConnector {
    let platformName = "Instagram"
    private let logger = Log.instagram
    private var accessToken: String?
    private var businessAccountID: String?
    
    // Internal struct for caching business account ID (distinct from PlatformCredentials.InstagramCredentials)
    struct InstagramCredentials: Codable {
        let businessAccountID: String
        let pageName: String
    }
    
    var isConfigured: Bool {
        get async {
            // First try loading cached credentials
            if let cached = try? KeychainService.shared.retrieve(InstagramCredentials.self, for: "instagram_business") {
                businessAccountID = cached.businessAccountID
            }
            
            do {
                let tokens = try OAuthManager.shared.getTokens(for: "instagram")
                accessToken = tokens.accessToken
                return accessToken != nil && businessAccountID != nil
            } catch {
                return false
            }
        }
    }
    
    func authenticate() async throws {
        let config = try OAuthManager.shared.getConfig(for: "instagram")
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "instagram",
            config: config
        )
        try OAuthManager.shared.saveTokens(tokens, for: "instagram")
        accessToken = tokens.accessToken
        
        // Discover the Instagram Business Account ID
        try await fetchInstagramBusinessAccountID(userToken: tokens.accessToken)
    }
    
    private func fetchInstagramBusinessAccountID(userToken: String) async throws {
        // Step 1: Get Pages (similar to Facebook flow)
        let pagesURL = URL(string: "https://graph.facebook.com/v24.0/me/accounts?access_token=\(userToken)")!
        let (pagesData, pagesResponse) = try await URLSession.shared.data(from: pagesURL)
        
        guard let httpResponse = pagesResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: pagesData, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to fetch pages for Instagram: \(errorBody)")
            throw PlatformError.postFailed("Failed to fetch pages for Instagram: \(errorBody)")
        }
        
        struct PagesResponse: Decodable {
            struct Page: Decodable {
                let id: String
                let name: String
                let access_token: String
            }
            let data: [Page]
        }
        
        let pagesResult = try JSONDecoder().decode(PagesResponse.self, from: pagesData)
        
        guard let page = pagesResult.data.first else {
            throw PlatformError.postFailed("No Facebook Pages found. Instagram Business accounts must be linked to a Facebook Page.")
        }
        
        // Use the first page or find "The Book of Wisdom"
        let targetPage = pagesResult.data.first(where: {
            $0.name.localizedCaseInsensitiveContains("wisdom") ||
            $0.name.localizedCaseInsensitiveContains("book")
        }) ?? page
        
        // Step 2: Get the Instagram Business Account ID from the Page
        let igURL = URL(string: "https://graph.facebook.com/v24.0/\(targetPage.id)?fields=instagram_business_account&access_token=\(targetPage.access_token)")!
        let (igData, igResponse) = try await URLSession.shared.data(from: igURL)
        
        guard let igHttp = igResponse as? HTTPURLResponse, igHttp.statusCode == 200 else {
            let errorBody = String(data: igData, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to get Instagram Business Account: \(errorBody)")
            throw PlatformError.postFailed("Failed to get Instagram Business Account: \(errorBody)")
        }
        
        struct IGAccountResponse: Decodable {
            struct IGAccount: Decodable {
                let id: String
            }
            let instagram_business_account: IGAccount?
        }
        
        let igResult = try JSONDecoder().decode(IGAccountResponse.self, from: igData)
        
        guard let igAccount = igResult.instagram_business_account else {
            throw PlatformError.postFailed("No Instagram Business Account linked to '\(targetPage.name)'. Go to your Facebook Page Settings → Instagram and connect your Instagram account.")
        }
        
        businessAccountID = igAccount.id
        
        // Also store the page access token for Instagram API calls
        // Instagram Content Publishing API uses the Page Access Token
        let igTokens = OAuthManager.OAuthTokens(
            accessToken: targetPage.access_token,
            refreshToken: nil,
            expiresAt: nil,
            tokenType: "bearer",
            scope: nil,
            idToken: nil
        )
        try OAuthManager.shared.saveTokens(igTokens, for: "instagram")
        accessToken = targetPage.access_token
        
        // Persist business account ID
        let creds = InstagramCredentials(
            businessAccountID: igAccount.id,
            pageName: targetPage.name
        )
        try KeychainService.shared.save(creds, for: "instagram_business")
        
        logger.info("Instagram Business Account connected: \(igAccount.id) (via page: \(targetPage.name))")
    }
    
    func configure(businessAccountID: String) {
        self.businessAccountID = businessAccountID
    }
    
    func postText(_ text: String) async throws -> PostResult {
        // Instagram doesn't support text-only posts, but we can post a link card
        // For now, return an error directing users to post with an image
        throw PlatformError.postFailed("Instagram requires an image. Please use the image post feature.")
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let token = accessToken, let accountID = businessAccountID else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        // Instagram requires images at a publicly accessible URL.
        // Upload to Facebook Page as an unpublished photo to get a CDN URL.
        let publicImageURL = try await uploadImageToFacebookCDN(imageData: imageData, token: token)
        
        let igCaption = "\(caption)\n\n📖 Read more at wisdombook.life (link in bio)"
        
        // Step 1: Create container with public image URL
        let containerID = try await createMediaContainer(
            imageURL: publicImageURL,
            caption: igCaption,
            accountID: accountID,
            token: token
        )
        
        // Step 2: Wait for container to be ready (Instagram processes async)
        try await waitForContainerReady(containerID: containerID, token: token)
        
        // Step 3: Publish the container
        let mediaID = try await publishContainer(containerID: containerID, accountID: accountID, token: token)
        
        logger.info("Instagram post published: \(mediaID)")
        
        // Get the permalink (shortcode URL) for the post
        let permalink = try? await fetchPermalink(mediaID: mediaID, token: token)
        
        return PostResult(
            success: true,
            postID: mediaID,
            postURL: permalink,
            error: nil
        )
    }
    
    func postVideo(_ videoURL: URL, caption: String) async throws -> PostResult {
        guard let token = accessToken, let accountID = businessAccountID else {
            throw PlatformError.notConfigured
        }
        
        logger.info("Posting video to Instagram (Reels)...")
        
        // 1. Upload video to a public URL (Facebook Page Video)
        // Instagram Graph API for video requires the video to be at a public URL.
        // We'll upload to Facebook Page as unpublished video to get a URL.
        let publicVideoURL = try await uploadVideoToFacebook(videoURL: videoURL, token: token)
        
        let igCaption = "\(caption)\n\n📖 Read more at wisdombook.life (link in bio)"
        
        // 2. Create Media Container (REELS)
        let containerID = try await createReelsContainer(
            videoURL: publicVideoURL,
            caption: igCaption,
            accountID: accountID,
            token: token
        )
        
        // 3. Wait for processing
        try await waitForContainerReady(containerID: containerID, token: token)
        
        // 4. Publish
        let mediaID = try await publishContainer(containerID: containerID, accountID: accountID, token: token)
        
        logger.info("Instagram Reel published: \(mediaID)")
        
        // Get the permalink (shortcode URL) for the reel
        let permalink = try? await fetchPermalink(mediaID: mediaID, token: token)
        
        return PostResult(
            success: true,
            postID: mediaID,
            postURL: permalink,
            error: nil
        )
    }
    
    /// Upload image to Facebook Page as an unpublished photo to get a public CDN URL for Instagram
    private func uploadImageToFacebookCDN(imageData: Data, token: String) async throws -> String {
        // Load Facebook Page credentials (we need the Page ID and Page Access Token)
        let pageCreds: FacebookPageCredentials
        do {
            pageCreds = try KeychainService.shared.retrieve(FacebookPageCredentials.self, for: "facebook_page")
        } catch {
            throw PlatformError.postFailed("Facebook Page not configured. Connect Facebook first to enable Instagram image hosting.")
        }
        
        // Upload as unpublished photo to Facebook Page
        let url = URL(string: "https://graph.facebook.com/v24.0/\(pageCreds.pageID)/photos")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Access token
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"access_token\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(pageCreds.pageAccessToken)\r\n".data(using: .utf8)!)
        
        // Published = false (don't show on page feed)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"published\"\r\n\r\n".data(using: .utf8)!)
        body.append("false\r\n".data(using: .utf8)!)
        
        // Image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source\"; filename=\"instagram_image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Facebook image upload failed: \(errorBody)")
        }
        
        struct PhotoResponse: Decodable {
            let id: String
        }
        
        let photoResponse = try JSONDecoder().decode(PhotoResponse.self, from: data)
        
        // Now get the CDN source URL of the uploaded photo
        let sourceURL = URL(string: "https://graph.facebook.com/v24.0/\(photoResponse.id)?fields=images&access_token=\(pageCreds.pageAccessToken)")!
        let (sourceData, sourceResponse) = try await URLSession.shared.data(from: sourceURL)
        
        guard let sourceHttp = sourceResponse as? HTTPURLResponse, sourceHttp.statusCode == 200 else {
            let errorBody = String(data: sourceData, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Failed to get image URL: \(errorBody)")
        }
        
        struct ImageResponse: Decodable {
            struct Image: Decodable {
                let source: String
                let width: Int
                let height: Int
            }
            let images: [Image]
        }
        
        let imageResponse = try JSONDecoder().decode(ImageResponse.self, from: sourceData)
        
        // Use the largest image (first in the array)
        guard let cdnURL = imageResponse.images.first?.source else {
            throw PlatformError.postFailed("No image URL returned from Facebook")
        }
        
        logger.info("Image uploaded to Facebook CDN: \(cdnURL.prefix(80))...")
        return cdnURL
    }
    
    /// Upload video to Facebook Page as unpublished to get a public URL for Instagram
    /// Uses resumable upload protocol for better reliability with larger files
    private func uploadVideoToFacebook(videoURL: URL, token: String) async throws -> String {
        let pageCreds: FacebookPageCredentials
        do {
            pageCreds = try KeychainService.shared.retrieve(FacebookPageCredentials.self, for: "facebook_page")
        } catch {
            throw PlatformError.postFailed("Facebook Page not configured. Required for hosting video.")
        }
        
        // Check file size
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let fileSizeMB = Double(fileSize) / 1024 / 1024
        logger.info("Uploading video to Facebook: \(String(format: "%.1f", fileSizeMB)) MB")
        
        // For files under 50MB, use simple upload; for larger files, use resumable upload
        if fileSizeMB < 50 {
            return try await uploadVideoSimple(videoURL: videoURL, pageCreds: pageCreds)
        } else {
            return try await uploadVideoResumable(videoURL: videoURL, fileSize: fileSize, pageCreds: pageCreds)
        }
    }
    
    /// Simple direct upload for smaller videos (< 50MB)
    private func uploadVideoSimple(videoURL: URL, pageCreds: FacebookPageCredentials) async throws -> String {
        let videoData = try Data(contentsOf: videoURL)
        let url = URL(string: "https://graph-video.facebook.com/v24.0/\(pageCreds.pageID)/videos")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Access Token
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"access_token\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(pageCreds.pageAccessToken)\r\n".data(using: .utf8)!)
        
        // Published = false
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"published\"\r\n\r\n".data(using: .utf8)!)
        body.append("false\r\n".data(using: .utf8)!)
        
        // Video Data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source\"; filename=\"video.mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Facebook video upload failed: \(errorBody)")
        }
        
        struct VideoResponse: Decodable {
            let id: String
        }
        let vidResp = try JSONDecoder().decode(VideoResponse.self, from: data)
        
        // Get Source URL
        let sourceURL = URL(string: "https://graph.facebook.com/v24.0/\(vidResp.id)?fields=source&access_token=\(pageCreds.pageAccessToken)")!
        let (sourceData, _) = try await URLSession.shared.data(from: sourceURL)
        
        struct VideoSourceResponse: Decodable {
            let source: String
        }
        let sourceResp = try JSONDecoder().decode(VideoSourceResponse.self, from: sourceData)
        return sourceResp.source
    }
    
    /// Resumable upload for larger videos (>= 50MB)
    /// Uses Facebook's resumable upload protocol with chunked transfer
    private func uploadVideoResumable(videoURL: URL, fileSize: Int64, pageCreds: FacebookPageCredentials) async throws -> String {
        logger.info("Using resumable upload for large video (\(fileSize / 1024 / 1024) MB)")
        
        // Step 1: Initialize upload session
        let initURL = URL(string: "https://graph.facebook.com/v24.0/\(pageCreds.pageID)/videos")!
        
        var initRequest = URLRequest(url: initURL)
        initRequest.httpMethod = "POST"
        initRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let initBody: [String: Any] = [
            "access_token": pageCreds.pageAccessToken,
            "published": false,
            "file_size": fileSize,
            "upload_phase": "start"
        ]
        
        initRequest.httpBody = try JSONSerialization.data(withJSONObject: initBody)
        
        let (initData, initResponse) = try await URLSession.shared.data(for: initRequest)
        
        guard let httpResponse = initResponse as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: initData, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Failed to initialize resumable upload: \(errorBody)")
        }
        
        struct InitResponse: Decodable {
            let upload_session_id: String?
            let video_id: String?
            let start_offset: String?
            let end_offset: String?
        }
        
        let initResp: InitResponse
        do {
            initResp = try JSONDecoder().decode(InitResponse.self, from: initData)
        } catch {
            let responseString = String(data: initData, encoding: .utf8) ?? "Unable to decode"
            logger.error("Failed to decode init response: \(responseString)")
            throw PlatformError.postFailed("Failed to parse upload init response: \(responseString)")
        }
        
        guard let sessionID = initResp.upload_session_id,
              let videoID = initResp.video_id else {
            let responseString = String(data: initData, encoding: .utf8) ?? "Unable to decode"
            logger.error("Missing session_id or video_id in response: \(responseString)")
            throw PlatformError.postFailed("Invalid upload init response: \(responseString)")
        }
        
        logger.info("Resumable upload initialized. Session: \(sessionID), Video ID: \(videoID)")
        
        // Step 2: Upload file in chunks (8MB chunks)
        let chunkSize = 8 * 1024 * 1024 // 8MB
        let fileHandle = try FileHandle(forReadingFrom: videoURL)
        defer { fileHandle.closeFile() }
        
        var startOffset = Int(initResp.start_offset ?? "0") ?? 0
        let endOffset = Int(initResp.end_offset ?? String(fileSize)) ?? Int(fileSize)
        
        while startOffset < endOffset {
            let currentChunkSize = min(chunkSize, endOffset - startOffset)
            fileHandle.seek(toFileOffset: UInt64(startOffset))
            let chunkData = fileHandle.readData(ofLength: currentChunkSize)
            
            logger.info("Uploading chunk: \(startOffset) - \(startOffset + currentChunkSize)")
            
            // Upload chunk
            let chunkURL = URL(string: "https://graph-video.facebook.com/v24.0/\(pageCreds.pageID)/videos")!
            
            var chunkRequest = URLRequest(url: chunkURL)
            chunkRequest.httpMethod = "POST"
            
            let boundary = UUID().uuidString
            chunkRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var chunkBody = Data()
            
            // Access Token
            chunkBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            chunkBody.append("Content-Disposition: form-data; name=\"access_token\"\r\n\r\n".data(using: .utf8)!)
            chunkBody.append("\(pageCreds.pageAccessToken)\r\n".data(using: .utf8)!)
            
            // Upload phase
            chunkBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            chunkBody.append("Content-Disposition: form-data; name=\"upload_phase\"\r\n\r\n".data(using: .utf8)!)
            chunkBody.append("transfer\r\n".data(using: .utf8)!)
            
            // Session ID
            chunkBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            chunkBody.append("Content-Disposition: form-data; name=\"upload_session_id\"\r\n\r\n".data(using: .utf8)!)
            chunkBody.append("\(sessionID)\r\n".data(using: .utf8)!)
            
            // Start offset
            chunkBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            chunkBody.append("Content-Disposition: form-data; name=\"start_offset\"\r\n\r\n".data(using: .utf8)!)
            chunkBody.append("\(startOffset)\r\n".data(using: .utf8)!)
            
            // Video chunk
            chunkBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            chunkBody.append("Content-Disposition: form-data; name=\"video_file_chunk\"; filename=\"chunk.bin\"\r\n".data(using: .utf8)!)
            chunkBody.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
            chunkBody.append(chunkData)
            chunkBody.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
            
            chunkRequest.httpBody = chunkBody
            
            let (chunkRespData, chunkResponse) = try await URLSession.shared.data(for: chunkRequest)
            
            guard let chunkHttpResp = chunkResponse as? HTTPURLResponse, chunkHttpResp.statusCode == 200 else {
                let errorBody = String(data: chunkRespData, encoding: .utf8) ?? "Unknown error"
                throw PlatformError.postFailed("Chunk upload failed: \(errorBody)")
            }
            
            struct ChunkResponse: Decodable {
                let start_offset: String?
                let end_offset: String?
            }
            
            let chunkResp = try JSONDecoder().decode(ChunkResponse.self, from: chunkRespData)
            
            if let nextOffset = chunkResp.start_offset {
                startOffset = Int(nextOffset) ?? endOffset
            } else {
                break
            }
        }
        
        // Step 3: Finish upload
        let finishURL = URL(string: "https://graph.facebook.com/v24.0/\(pageCreds.pageID)/videos")!
        
        var finishRequest = URLRequest(url: finishURL)
        finishRequest.httpMethod = "POST"
        finishRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let finishBody: [String: Any] = [
            "access_token": pageCreds.pageAccessToken,
            "upload_phase": "finish",
            "upload_session_id": sessionID
        ]
        
        finishRequest.httpBody = try JSONSerialization.data(withJSONObject: finishBody)
        
        let (finishData, finishResponse) = try await URLSession.shared.data(for: finishRequest)
        
        guard let finishHttpResp = finishResponse as? HTTPURLResponse, finishHttpResp.statusCode == 200 else {
            let errorBody = String(data: finishData, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Failed to finish upload: \(errorBody)")
        }
        
        struct FinishResponse: Decodable {
            let success: Bool?
        }
        
        let _ = try JSONDecoder().decode(FinishResponse.self, from: finishData)
        
        logger.info("Resumable upload complete. Video ID: \(videoID)")
        
        // Get Source URL
        let sourceURL = URL(string: "https://graph.facebook.com/v24.0/\(videoID)?fields=source&access_token=\(pageCreds.pageAccessToken)")!
        let (sourceData, _) = try await URLSession.shared.data(from: sourceURL)
        
        struct VideoSourceResponse: Decodable {
            let source: String
        }
        let sourceResp = try JSONDecoder().decode(VideoSourceResponse.self, from: sourceData)
        return sourceResp.source
    }
    
    private func createMediaContainer(imageURL: String, caption: String, accountID: String, token: String) async throws -> String {
        var components = URLComponents(string: "https://graph.facebook.com/v24.0/\(accountID)/media")!
        components.queryItems = [
            URLQueryItem(name: "image_url", value: imageURL),
            URLQueryItem(name: "caption", value: caption),
            URLQueryItem(name: "access_token", value: token)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Instagram] Container creation failed: \(errorBody)")
            throw PlatformError.postFailed("Container creation failed: \(errorBody)")
        }
        
        struct ContainerResponse: Decodable {
            let id: String
        }
        
        let containerResponse = try JSONDecoder().decode(ContainerResponse.self, from: data)
        return containerResponse.id
    }
    
    private func createReelsContainer(videoURL: String, caption: String, accountID: String, token: String) async throws -> String {
        var components = URLComponents(string: "https://graph.facebook.com/v24.0/\(accountID)/media")!
        components.queryItems = [
            URLQueryItem(name: "media_type", value: "REELS"),
            URLQueryItem(name: "video_url", value: videoURL),
            URLQueryItem(name: "caption", value: caption),
            URLQueryItem(name: "access_token", value: token)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Reels container creation failed: \(errorBody)")
        }
        
        struct ContainerResponse: Decodable {
            let id: String
        }
        return try JSONDecoder().decode(ContainerResponse.self, from: data).id
    }
    
    private func publishContainer(containerID: String, accountID: String, token: String) async throws -> String {
        var components = URLComponents(string: "https://graph.facebook.com/v24.0/\(accountID)/media_publish")!
        components.queryItems = [
            URLQueryItem(name: "creation_id", value: containerID),
            URLQueryItem(name: "access_token", value: token)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[Instagram] Publish failed: \(errorBody)")
            throw PlatformError.postFailed("Publish failed: \(errorBody)")
        }
        
        struct PublishResponse: Decodable {
            let id: String
        }
        
        let publishResponse = try JSONDecoder().decode(PublishResponse.self, from: data)
        return publishResponse.id
    }
    
    /// Poll container status until FINISHED (Instagram processes media asynchronously)
    private func waitForContainerReady(containerID: String, token: String, maxAttempts: Int = 10) async throws {
        // Initial wait — container always needs some processing time
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        for attempt in 1...maxAttempts {
            let status = try await checkContainerStatus(containerID: containerID, token: token)
            
            if status == "FINISHED" {
                // Brief extra delay — Instagram can report FINISHED before truly ready
                try await Task.sleep(nanoseconds: 2_000_000_000)
                print("[Instagram] Container ready after \(attempt) poll(s)")
                return
            } else if status == "ERROR" {
                throw PlatformError.postFailed("Instagram container processing failed")
            }
            
            // Wait 3 seconds before next poll
            print("[Instagram] Container status: \(status) (attempt \(attempt)/\(maxAttempts))")
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        
        throw PlatformError.postFailed("Instagram container not ready after \(maxAttempts) attempts")
    }
    
    private func checkContainerStatus(containerID: String, token: String) async throws -> String {
        let url = URL(string: "https://graph.facebook.com/v24.0/\(containerID)?fields=status_code&access_token=\(token)")!
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct StatusResponse: Decodable {
            let status_code: String?
        }
        
        let statusResponse = try JSONDecoder().decode(StatusResponse.self, from: data)
        return statusResponse.status_code ?? "UNKNOWN"
    }
    
    /// Fetch the permalink (shortcode URL) for a published media
    private func fetchPermalink(mediaID: String, token: String) async throws -> URL? {
        let url = URL(string: "https://graph.facebook.com/v24.0/\(mediaID)?fields=permalink&access_token=\(token)")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            logger.warning("Failed to fetch permalink for media \(mediaID)")
            return nil
        }
        
        struct PermalinkResponse: Decodable {
            let permalink: String?
        }
        
        let permalinkResponse = try JSONDecoder().decode(PermalinkResponse.self, from: data)
        
        if let permalink = permalinkResponse.permalink {
            logger.info("Fetched permalink: \(permalink)")
            return URL(string: permalink)
        }
        
        return nil
    }
}
