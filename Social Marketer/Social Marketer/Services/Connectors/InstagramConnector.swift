//
//  InstagramConnector.swift
//  SocialMarketer
//
//  Refactored to use BasePlatformConnector and MultipartFormBuilder.
//

import Foundation
import AppKit

// MARK: - Instagram Connector

final class InstagramConnector: BasePlatformConnector, VideoPlatformConnector {
    
    override var platformName: String { "Instagram" }
    
    private var accessToken: String?
    private var businessAccountID: String?
    
    // Internal struct for caching business account ID
    struct InstagramCredentials: Codable {
        let businessAccountID: String
        let pageName: String
    }
    
    var isConfigured: Bool {
        get async {
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
        let tokens = try await performOAuthAuthentication()
        accessToken = tokens.accessToken
        try await fetchInstagramBusinessAccountID(userToken: tokens.accessToken)
    }
    
    private func fetchInstagramBusinessAccountID(userToken: String) async throws {
        // Step 1: Get Pages
        let pagesURL = URL(string: "https://graph.facebook.com/v24.0/me/accounts?access_token=\(userToken)")!
        let pagesResponse = try await performJSONRequest(getRequest(url: pagesURL), decoding: PagesResponse.self)
        
        guard let page = pagesResponse.data.first else {
            throw PlatformError.postFailed("No Facebook Pages found. Instagram Business accounts must be linked to a Facebook Page.")
        }
        
        let targetPage = pagesResponse.data.first(where: {
            $0.name.localizedCaseInsensitiveContains("wisdom") ||
            $0.name.localizedCaseInsensitiveContains("book")
        }) ?? page
        
        // Step 2: Get Instagram Business Account ID
        let igURL = URL(string: "https://graph.facebook.com/v24.0/\(targetPage.id)?fields=instagram_business_account&access_token=\(targetPage.access_token)")!
        let igResponse = try await performJSONRequest(getRequest(url: igURL), decoding: IGAccountResponse.self)
        
        guard let igAccount = igResponse.instagram_business_account else {
            throw PlatformError.postFailed("No Instagram Business Account linked to '\(targetPage.name)'.")
        }
        
        businessAccountID = igAccount.id
        
        // Store Page Access Token for Instagram API calls
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
        
        // Persist credentials
        let creds = InstagramCredentials(
            businessAccountID: igAccount.id,
            pageName: targetPage.name
        )
        try KeychainService.shared.save(creds, for: "instagram_business")
        
        logInfo("Instagram Business Account connected: \(igAccount.id) (via page: \(targetPage.name))")
    }
    
    func configure(businessAccountID: String) {
        self.businessAccountID = businessAccountID
    }
    
    func postText(_ text: String) async throws -> PostResult {
        throw PlatformError.postFailed("Instagram requires an image. Please use the image post feature.")
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let token = accessToken, let accountID = businessAccountID else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        let publicImageURL = try await uploadImageToFacebookCDN(imageData: imageData, token: token)
        let igCaption = "\(caption)\n\n📖 Read more at \(AppConfiguration.URLs.wisdomBookDomain) (link in bio)"
        
        let containerID = try await createMediaContainer(
            imageURL: publicImageURL,
            caption: igCaption,
            accountID: accountID,
            token: token
        )
        
        try await waitForContainerReady(containerID: containerID, token: token)
        let mediaID = try await publishContainer(containerID: containerID, accountID: accountID, token: token)
        
        logInfo("Instagram post published: \(mediaID)")
        
        let permalink = try? await fetchPermalink(mediaID: mediaID, token: token)
        
        return PostResult(success: true, postID: mediaID, postURL: permalink, error: nil)
    }
    
    func postVideo(_ videoURL: URL, caption: String) async throws -> PostResult {
        guard let token = accessToken, let accountID = businessAccountID else {
            throw PlatformError.notConfigured
        }
        
        logInfo("Posting video to Instagram (Reels)...")
        
        let publicVideoURL = try await uploadVideoToFacebook(videoURL: videoURL, token: token)
        let igCaption = "\(caption)\n\n📖 Read more at \(AppConfiguration.URLs.wisdomBookDomain) (link in bio)"
        
        let containerID = try await createReelsContainer(
            videoURL: publicVideoURL,
            caption: igCaption,
            accountID: accountID,
            token: token
        )
        
        try await waitForContainerReady(containerID: containerID, token: token)
        let mediaID = try await publishContainer(containerID: containerID, accountID: accountID, token: token)
        
        logInfo("Instagram Reel published: \(mediaID)")
        
        let permalink = try? await fetchPermalink(mediaID: mediaID, token: token)
        
        return PostResult(success: true, postID: mediaID, postURL: permalink, error: nil)
    }
    
    // MARK: - Facebook CDN Uploads
    
    private func uploadImageToFacebookCDN(imageData: Data, token: String) async throws -> String {
        guard let pageCreds = try? KeychainService.shared.retrieve(FacebookPageCredentials.self, for: "facebook_page") else {
            throw PlatformError.postFailed("Facebook Page not configured. Connect Facebook first.")
        }
        
        let url = URL(string: "https://graph.facebook.com/v24.0/\(pageCreds.pageID)/photos")!
        
        // Use MultipartFormBuilder
        var builder = MultipartFormBuilder()
        builder.addField(name: "access_token", value: pageCreds.pageAccessToken)
        builder.addField(name: "published", value: "false")
        builder.addJPEGImage(name: "source", filename: "instagram_image.jpg", data: imageData)
        
        let (body, contentType) = builder.build()
        let request = postRequest(url: url, body: body, contentType: contentType)
        
        let photoResponse = try await performJSONRequest(request, decoding: PhotoResponse.self)
        
        // Get CDN URL
        let sourceURL = URL(string: "https://graph.facebook.com/v24.0/\(photoResponse.id)?fields=images&access_token=\(pageCreds.pageAccessToken)")!
        let imageResponse = try await performJSONRequest(getRequest(url: sourceURL), decoding: ImageResponse.self)
        
        guard let cdnURL = imageResponse.images.first?.source else {
            throw PlatformError.postFailed("No image URL returned from Facebook")
        }
        
        logInfo("Image uploaded to Facebook CDN: \(cdnURL.prefix(80))...")
        return cdnURL
    }
    
    private func uploadVideoToFacebook(videoURL: URL, token: String) async throws -> String {
        guard let pageCreds = try? KeychainService.shared.retrieve(FacebookPageCredentials.self, for: "facebook_page") else {
            throw PlatformError.postFailed("Facebook Page not configured. Required for hosting video.")
        }
        
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: videoURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let fileSizeMB = Double(fileSize) / 1024 / 1024
        
        logInfo("Uploading video to Facebook: \(String(format: "%.1f", fileSizeMB)) MB")
        
        if fileSizeMB < 50 {
            return try await uploadVideoSimple(videoURL: videoURL, pageCreds: pageCreds)
        } else {
            return try await uploadVideoResumable(videoURL: videoURL, fileSize: fileSize, pageCreds: pageCreds)
        }
    }
    
    private func uploadVideoSimple(videoURL: URL, pageCreds: FacebookPageCredentials) async throws -> String {
        let videoData = try Data(contentsOf: videoURL)
        let url = URL(string: "https://graph-video.facebook.com/v24.0/\(pageCreds.pageID)/videos")!
        
        var builder = MultipartFormBuilder()
        builder.addField(name: "access_token", value: pageCreds.pageAccessToken)
        builder.addField(name: "published", value: "false")
        builder.addMP4Video(name: "source", data: videoData)
        
        let (body, contentType) = builder.build()
        let request = postRequest(url: url, body: body, contentType: contentType)
        
        let vidResp = try await performJSONRequest(request, decoding: VideoResponse.self)
        
        // Get source URL
        let sourceURL = URL(string: "https://graph.facebook.com/v24.0/\(vidResp.id)?fields=source&access_token=\(pageCreds.pageAccessToken)")!
        let sourceResp = try await performJSONRequest(getRequest(url: sourceURL), decoding: VideoSourceResponse.self)
        
        return sourceResp.source
    }
    
    private func uploadVideoResumable(videoURL: URL, fileSize: Int64, pageCreds: FacebookPageCredentials) async throws -> String {
        logInfo("Using resumable upload for large video (\(fileSize / 1024 / 1024) MB)")
        
        // Step 1: Initialize upload
        let initURL = URL(string: "https://graph.facebook.com/v24.0/\(pageCreds.pageID)/videos")!
        
        let initBody: [String: Any] = [
            "access_token": pageCreds.pageAccessToken,
            "published": false,
            "file_size": fileSize,
            "upload_phase": "start"
        ]
        
        var initRequest = postRequest(url: initURL, body: try JSONSerialization.data(withJSONObject: initBody), contentType: "application/json")
        let initResp = try await performJSONRequest(initRequest, decoding: InitResponse.self)
        
        guard let sessionID = initResp.upload_session_id, let videoID = initResp.video_id else {
            throw PlatformError.postFailed("Invalid upload init response")
        }
        
        logInfo("Resumable upload initialized. Session: \(sessionID), Video ID: \(videoID)")
        
        // Step 2: Upload chunks
        let chunkSize = 8 * 1024 * 1024
        let fileHandle = try FileHandle(forReadingFrom: videoURL)
        defer { fileHandle.closeFile() }
        
        var startOffset = Int(initResp.start_offset ?? "0") ?? 0
        let endOffset = Int(initResp.end_offset ?? String(fileSize)) ?? Int(fileSize)
        
        while startOffset < endOffset {
            let currentChunkSize = min(chunkSize, endOffset - startOffset)
            fileHandle.seek(toFileOffset: UInt64(startOffset))
            let chunkData = fileHandle.readData(ofLength: currentChunkSize)
            
            logInfo("Uploading chunk: \(startOffset) - \(startOffset + currentChunkSize)")
            
            let chunkURL = URL(string: "https://graph-video.facebook.com/v24.0/\(pageCreds.pageID)/videos")!
            
            var builder = MultipartFormBuilder()
            builder.addField(name: "access_token", value: pageCreds.pageAccessToken)
            builder.addField(name: "upload_phase", value: "transfer")
            builder.addField(name: "upload_session_id", value: sessionID)
            builder.addField(name: "start_offset", value: String(startOffset))
            builder.addFile(name: "video_file_chunk", filename: "chunk.bin", contentType: "application/octet-stream", data: chunkData)
            
            let (body, contentType) = builder.build()
            let request = postRequest(url: chunkURL, body: body, contentType: contentType)
            
            let chunkResp = try await performJSONRequest(request, decoding: ChunkResponse.self)
            
            if let nextOffset = chunkResp.start_offset {
                startOffset = Int(nextOffset) ?? endOffset
            } else {
                break
            }
        }
        
        // Step 3: Finish upload
        let finishURL = URL(string: "https://graph.facebook.com/v24.0/\(pageCreds.pageID)/videos")!
        let finishBody: [String: Any] = [
            "access_token": pageCreds.pageAccessToken,
            "upload_phase": "finish",
            "upload_session_id": sessionID
        ]
        
        var finishRequest = postRequest(url: finishURL, body: try JSONSerialization.data(withJSONObject: finishBody), contentType: "application/json")
        _ = try await performJSONRequest(finishRequest, decoding: FinishResponse.self)
        
        logInfo("Resumable upload complete. Video ID: \(videoID)")
        
        // Get source URL
        let sourceURL = URL(string: "https://graph.facebook.com/v24.0/\(videoID)?fields=source&access_token=\(pageCreds.pageAccessToken)")!
        let sourceResp = try await performJSONRequest(getRequest(url: sourceURL), decoding: VideoSourceResponse.self)
        
        return sourceResp.source
    }
    
    // MARK: - Instagram Containers
    
    private func createMediaContainer(imageURL: String, caption: String, accountID: String, token: String) async throws -> String {
        var components = URLComponents(string: "https://graph.facebook.com/v24.0/\(accountID)/media")!
        components.queryItems = [
            URLQueryItem(name: "image_url", value: imageURL),
            URLQueryItem(name: "caption", value: caption),
            URLQueryItem(name: "access_token", value: token)
        ]
        
        let request = postRequest(url: components.url!)
        let response = try await performJSONRequest(request, decoding: ContainerResponse.self)
        return response.id
    }
    
    private func createReelsContainer(videoURL: String, caption: String, accountID: String, token: String) async throws -> String {
        var components = URLComponents(string: "https://graph.facebook.com/v24.0/\(accountID)/media")!
        components.queryItems = [
            URLQueryItem(name: "media_type", value: "REELS"),
            URLQueryItem(name: "video_url", value: videoURL),
            URLQueryItem(name: "caption", value: caption),
            URLQueryItem(name: "access_token", value: token)
        ]
        
        let request = postRequest(url: components.url!)
        let response = try await performJSONRequest(request, decoding: ContainerResponse.self)
        return response.id
    }
    
    private func publishContainer(containerID: String, accountID: String, token: String) async throws -> String {
        var components = URLComponents(string: "https://graph.facebook.com/v24.0/\(accountID)/media_publish")!
        components.queryItems = [
            URLQueryItem(name: "creation_id", value: containerID),
            URLQueryItem(name: "access_token", value: token)
        ]
        
        let request = postRequest(url: components.url!)
        let response = try await performJSONRequest(request, decoding: PublishResponse.self)
        return response.id
    }
    
    private func waitForContainerReady(containerID: String, token: String, maxAttempts: Int = 10) async throws {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        for attempt in 1...maxAttempts {
            let status = try await checkContainerStatus(containerID: containerID, token: token)
            
            if status == "FINISHED" {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                print("[Instagram] Container ready after \(attempt) poll(s)")
                return
            } else if status == "ERROR" {
                throw PlatformError.postFailed("Instagram container processing failed")
            }
            
            print("[Instagram] Container status: \(status) (attempt \(attempt)/\(maxAttempts))")
            try await Task.sleep(nanoseconds: 3_000_000_000)
        }
        
        throw PlatformError.postFailed("Instagram container not ready after \(maxAttempts) attempts")
    }
    
    private func checkContainerStatus(containerID: String, token: String) async throws -> String {
        let url = URL(string: "https://graph.facebook.com/v24.0/\(containerID)?fields=status_code&access_token=\(token)")!
        let response = try await performJSONRequest(getRequest(url: url), decoding: StatusResponse.self)
        return response.status_code ?? "UNKNOWN"
    }
    
    private func fetchPermalink(mediaID: String, token: String) async throws -> URL? {
        let url = URL(string: "https://graph.facebook.com/v24.0/\(mediaID)?fields=permalink&access_token=\(token)")!
        let response = try await performJSONRequest(getRequest(url: url), decoding: PermalinkResponse.self)
        
        if let permalink = response.permalink {
            logInfo("Fetched permalink: \(permalink)")
            return URL(string: permalink)
        }
        return nil
    }
    
    // MARK: - Response Types
    
    private struct PagesResponse: Decodable {
        struct Page: Decodable {
            let id: String
            let name: String
            let access_token: String
        }
        let data: [Page]
    }
    
    private struct IGAccountResponse: Decodable {
        struct IGAccount: Decodable {
            let id: String
        }
        let instagram_business_account: IGAccount?
    }
    
    private struct PhotoResponse: Decodable {
        let id: String
    }
    
    private struct ImageResponse: Decodable {
        struct Image: Decodable {
            let source: String
            let width: Int
            let height: Int
        }
        let images: [Image]
    }
    
    private struct VideoResponse: Decodable {
        let id: String
    }
    
    private struct VideoSourceResponse: Decodable {
        let source: String
    }
    
    private struct InitResponse: Decodable {
        let upload_session_id: String?
        let video_id: String?
        let start_offset: String?
        let end_offset: String?
    }
    
    private struct ChunkResponse: Decodable {
        let start_offset: String?
        let end_offset: String?
    }
    
    private struct FinishResponse: Decodable {
        let success: Bool?
    }
    
    private struct ContainerResponse: Decodable {
        let id: String
    }
    
    private struct PublishResponse: Decodable {
        let id: String
    }
    
    private struct StatusResponse: Decodable {
        let status_code: String?
    }
    
    private struct PermalinkResponse: Decodable {
        let permalink: String?
    }
}
