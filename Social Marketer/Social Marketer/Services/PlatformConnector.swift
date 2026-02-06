//
//  PlatformConnector.swift
//  SocialMarketer
//
//  Protocol and implementations for social media platform APIs
//

import Foundation
import AppKit
import os.log

/// Protocol for all platform connectors
protocol PlatformConnector {
    var platformName: String { get }
    var isConfigured: Bool { get async }
    
    func authenticate() async throws
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult
}

/// Result of a platform post
struct PostResult {
    let success: Bool
    let postID: String?
    let postURL: URL?
    let error: Error?
}

// MARK: - Platform Configurations

struct PlatformCredentials: Codable {
    var twitter: TwitterCredentials?
    var instagram: InstagramCredentials?
    var linkedin: LinkedInCredentials?
    var facebook: FacebookCredentials?
    var pinterest: PinterestCredentials?
    
    struct TwitterCredentials: Codable {
        let accessToken: String
        let refreshToken: String?
    }
    
    struct InstagramCredentials: Codable {
        let accessToken: String
        let businessAccountID: String
    }
    
    struct LinkedInCredentials: Codable {
        let accessToken: String
        let personURN: String
    }
    
    struct FacebookCredentials: Codable {
        let accessToken: String
        let pageID: String
        let pageAccessToken: String
    }
    
    struct PinterestCredentials: Codable {
        let accessToken: String
        let boardID: String
    }
}

// MARK: - Image Helper

private extension NSImage {
    func jpegData(compressionQuality: CGFloat = 0.9) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

// MARK: - Twitter/X Connector

final class TwitterConnector: PlatformConnector {
    let platformName = "X (Twitter)"
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "Twitter")
    private var accessToken: String?
    
    var isConfigured: Bool {
        get async {
            do {
                let tokens = try OAuthManager.shared.getTokens(for: "twitter")
                accessToken = tokens.accessToken
                return true
            } catch {
                return false
            }
        }
    }
    
    func authenticate() async throws {
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "twitter",
            config: .twitter
        )
        try OAuthManager.shared.saveTokens(tokens, for: "twitter")
        accessToken = tokens.accessToken
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let token = accessToken else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        // Step 1: Upload media using v2 media upload
        let mediaID = try await uploadMedia(imageData: imageData, token: token)
        
        // Step 2: Create tweet with media
        let fullCaption = "\(caption)\n\n🔗 \(link.absoluteString)"
        let tweetResult = try await createTweet(text: fullCaption, mediaID: mediaID, token: token)
        
        logger.info("Tweet posted successfully: \(tweetResult.id)")
        
        let postURL = URL(string: "https://twitter.com/i/status/\(tweetResult.id)")
        return PostResult(success: true, postID: tweetResult.id, postURL: postURL, error: nil)
    }
    
    private func uploadMedia(imageData: Data, token: String) async throws -> String {
        // X API v2 media upload (chunked for images > 5MB, simple for smaller)
        let url = URL(string: "https://upload.twitter.com/1.1/media/upload.json")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Media upload failed: \(errorBody)")
            throw PlatformError.postFailed("Media upload failed: \(errorBody)")
        }
        
        struct MediaResponse: Decodable {
            let media_id_string: String
        }
        
        let mediaResponse = try JSONDecoder().decode(MediaResponse.self, from: data)
        return mediaResponse.media_id_string
    }
    
    private func createTweet(text: String, mediaID: String, token: String) async throws -> (id: String, text: String) {
        let url = URL(string: "https://api.twitter.com/2/tweets")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "text": text,
            "media": ["media_ids": [mediaID]]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Tweet creation failed: \(errorBody)")
            throw PlatformError.postFailed("Tweet creation failed: \(errorBody)")
        }
        
        struct TweetResponse: Decodable {
            struct Data: Decodable {
                let id: String
                let text: String
            }
            let data: Data
        }
        
        let tweetResponse = try JSONDecoder().decode(TweetResponse.self, from: data)
        return (tweetResponse.data.id, tweetResponse.data.text)
    }
}

// MARK: - Instagram Connector

final class InstagramConnector: PlatformConnector {
    let platformName = "Instagram"
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "Instagram")
    private var accessToken: String?
    private var businessAccountID: String?
    
    var isConfigured: Bool {
        get async {
            do {
                let tokens = try OAuthManager.shared.getTokens(for: "facebook") // Instagram uses Facebook auth
                accessToken = tokens.accessToken
                // Business account ID should be stored separately after initial setup
                return accessToken != nil
            } catch {
                return false
            }
        }
    }
    
    func configure(businessAccountID: String) {
        self.businessAccountID = businessAccountID
    }
    
    func authenticate() async throws {
        // Instagram uses Facebook OAuth
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "facebook",
            config: .facebook
        )
        try OAuthManager.shared.saveTokens(tokens, for: "facebook")
        accessToken = tokens.accessToken
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let token = accessToken, let accountID = businessAccountID else {
            throw PlatformError.notConfigured
        }
        
        // Instagram requires image to be hosted at a public URL
        // For now, we'll use the image upload approach
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        // Step 1: Create media container (Instagram requires hosted image URL)
        // Note: In production, you'd upload to a CDN first
        let igCaption = "\(caption)\n\n📖 Read more at wisdombook.life (link in bio)"
        
        // Step 1: Create container with image URL
        let containerID = try await createMediaContainer(
            imageURL: "https://wisdombook.life/temp-image.jpg", // Placeholder - needs CDN
            caption: igCaption,
            accountID: accountID,
            token: token
        )
        
        // Step 2: Publish the container
        let mediaID = try await publishContainer(containerID: containerID, accountID: accountID, token: token)
        
        logger.info("Instagram post published: \(mediaID)")
        
        return PostResult(
            success: true,
            postID: mediaID,
            postURL: URL(string: "https://instagram.com/p/\(mediaID)"),
            error: nil
        )
    }
    
    private func createMediaContainer(imageURL: String, caption: String, accountID: String, token: String) async throws -> String {
        var components = URLComponents(string: "https://graph.facebook.com/v19.0/\(accountID)/media")!
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
            throw PlatformError.postFailed("Container creation failed: \(errorBody)")
        }
        
        struct ContainerResponse: Decodable {
            let id: String
        }
        
        let containerResponse = try JSONDecoder().decode(ContainerResponse.self, from: data)
        return containerResponse.id
    }
    
    private func publishContainer(containerID: String, accountID: String, token: String) async throws -> String {
        var components = URLComponents(string: "https://graph.facebook.com/v19.0/\(accountID)/media_publish")!
        components.queryItems = [
            URLQueryItem(name: "creation_id", value: containerID),
            URLQueryItem(name: "access_token", value: token)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Publish failed: \(errorBody)")
        }
        
        struct PublishResponse: Decodable {
            let id: String
        }
        
        let publishResponse = try JSONDecoder().decode(PublishResponse.self, from: data)
        return publishResponse.id
    }
}

// MARK: - LinkedIn Connector

final class LinkedInConnector: PlatformConnector {
    let platformName = "LinkedIn"
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "LinkedIn")
    private var accessToken: String?
    private var personURN: String?
    
    var isConfigured: Bool {
        get async {
            do {
                let tokens = try OAuthManager.shared.getTokens(for: "linkedin")
                accessToken = tokens.accessToken
                return true
            } catch {
                return false
            }
        }
    }
    
    func configure(personURN: String) {
        self.personURN = personURN
    }
    
    func authenticate() async throws {
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "linkedin",
            config: .linkedin
        )
        try OAuthManager.shared.saveTokens(tokens, for: "linkedin")
        accessToken = tokens.accessToken
        
        // Fetch person URN
        personURN = try await fetchPersonURN(token: tokens.accessToken)
    }
    
    private func fetchPersonURN(token: String) async throws -> String {
        let url = URL(string: "https://api.linkedin.com/v2/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        struct UserInfo: Decodable {
            let sub: String
        }
        
        let userInfo = try JSONDecoder().decode(UserInfo.self, from: data)
        return "urn:li:person:\(userInfo.sub)"
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let token = accessToken, let urn = personURN else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.pngData() else {
            throw PlatformError.postFailed("Failed to convert image to PNG")
        }
        
        // Step 1: Register image upload
        let (uploadURL, imageURN) = try await registerImageUpload(personURN: urn, token: token)
        
        // Step 2: Upload the image binary
        try await uploadImage(data: imageData, to: uploadURL, token: token)
        
        // Step 3: Create UGC post with image
        let fullCaption = "\(caption)\n\n🔗 \(link.absoluteString)"
        let postID = try await createPost(text: fullCaption, imageURN: imageURN, personURN: urn, token: token)
        
        logger.info("LinkedIn post created: \(postID)")
        
        return PostResult(
            success: true,
            postID: postID,
            postURL: URL(string: "https://www.linkedin.com/feed/update/\(postID)"),
            error: nil
        )
    }
    
    private func registerImageUpload(personURN: String, token: String) async throws -> (uploadURL: URL, imageURN: String) {
        let url = URL(string: "https://api.linkedin.com/v2/images?action=initializeUpload")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "initializeUploadRequest": [
                "owner": personURN
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Image registration failed: \(errorBody)")
        }
        
        struct RegisterResponse: Decodable {
            struct Value: Decodable {
                let uploadUrl: String
                let image: String
            }
            let value: Value
        }
        
        let registerResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
        guard let uploadURL = URL(string: registerResponse.value.uploadUrl) else {
            throw PlatformError.postFailed("Invalid upload URL")
        }
        
        return (uploadURL, registerResponse.value.image)
    }
    
    private func uploadImage(data: Data, to url: URL, token: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw PlatformError.postFailed("Image upload failed")
        }
    }
    
    private func createPost(text: String, imageURN: String, personURN: String, token: String) async throws -> String {
        let url = URL(string: "https://api.linkedin.com/v2/posts")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "author": personURN,
            "commentary": text,
            "visibility": "PUBLIC",
            "distribution": [
                "feedDistribution": "MAIN_FEED",
                "targetEntities": [],
                "thirdPartyDistributionChannels": []
            ],
            "content": [
                "media": [
                    "id": imageURN
                ]
            ],
            "lifecycleState": "PUBLISHED",
            "isReshareDisabledByAuthor": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Post creation failed: \(errorBody)")
        }
        
        // Get post ID from x-restli-id header
        if let postID = httpResponse.value(forHTTPHeaderField: "x-restli-id") {
            return postID
        }
        
        throw PlatformError.postFailed("No post ID returned")
    }
}

// MARK: - Facebook Connector

final class FacebookConnector: PlatformConnector {
    let platformName = "Facebook"
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "Facebook")
    private var accessToken: String?
    private var pageID: String?
    private var pageAccessToken: String?
    
    var isConfigured: Bool {
        get async {
            do {
                let tokens = try OAuthManager.shared.getTokens(for: "facebook")
                accessToken = tokens.accessToken
                return pageID != nil && pageAccessToken != nil
            } catch {
                return false
            }
        }
    }
    
    func configure(pageID: String, pageAccessToken: String) {
        self.pageID = pageID
        self.pageAccessToken = pageAccessToken
    }
    
    func authenticate() async throws {
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "facebook",
            config: .facebook
        )
        try OAuthManager.shared.saveTokens(tokens, for: "facebook")
        accessToken = tokens.accessToken
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let pageToken = pageAccessToken, let page = pageID else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        let fullCaption = "\(caption)\n\n🔗 \(link.absoluteString)"
        
        // Facebook Graph API - Post photo to page
        let url = URL(string: "https://graph.facebook.com/v19.0/\(page)/photos")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add access token
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"access_token\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(pageToken)\r\n".data(using: .utf8)!)
        
        // Add message
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"message\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(fullCaption)\r\n".data(using: .utf8)!)
        
        // Add image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"source\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Facebook post failed: \(errorBody)")
            throw PlatformError.postFailed("Facebook post failed: \(errorBody)")
        }
        
        struct PhotoResponse: Decodable {
            let id: String
            let post_id: String?
        }
        
        let photoResponse = try JSONDecoder().decode(PhotoResponse.self, from: data)
        
        logger.info("Facebook photo posted: \(photoResponse.id)")
        
        return PostResult(
            success: true,
            postID: photoResponse.post_id ?? photoResponse.id,
            postURL: URL(string: "https://facebook.com/\(photoResponse.id)"),
            error: nil
        )
    }
}

// MARK: - Pinterest Connector

final class PinterestConnector: PlatformConnector {
    let platformName = "Pinterest"
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "Pinterest")
    private var accessToken: String?
    private var boardID: String?
    
    var isConfigured: Bool {
        get async {
            do {
                let tokens = try OAuthManager.shared.getTokens(for: "pinterest")
                accessToken = tokens.accessToken
                return boardID != nil
            } catch {
                return false
            }
        }
    }
    
    func configure(boardID: String) {
        self.boardID = boardID
    }
    
    func authenticate() async throws {
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "pinterest",
            config: .pinterest
        )
        try OAuthManager.shared.saveTokens(tokens, for: "pinterest")
        accessToken = tokens.accessToken
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let token = accessToken, let board = boardID else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        // Step 1: Upload media
        let mediaID = try await uploadMedia(imageData: imageData, token: token)
        
        // Step 2: Create pin
        let pin = try await createPin(
            mediaID: mediaID,
            boardID: board,
            title: String(caption.prefix(100)), // Pinterest title limit
            description: caption,
            link: link,
            token: token
        )
        
        logger.info("Pinterest pin created: \(pin.id)")
        
        return PostResult(
            success: true,
            postID: pin.id,
            postURL: URL(string: "https://pinterest.com/pin/\(pin.id)"),
            error: nil
        )
    }
    
    private func uploadMedia(imageData: Data, token: String) async throws -> String {
        let url = URL(string: "https://api.pinterest.com/v5/media")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let base64Image = imageData.base64EncodedString()
        let payload: [String: Any] = [
            "media_type": "image",
            "media": base64Image
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Media upload failed: \(errorBody)")
        }
        
        struct MediaResponse: Decodable {
            let media_id: String
        }
        
        let mediaResponse = try JSONDecoder().decode(MediaResponse.self, from: data)
        return mediaResponse.media_id
    }
    
    private func createPin(mediaID: String, boardID: String, title: String, description: String, link: URL, token: String) async throws -> (id: String, url: String?) {
        let url = URL(string: "https://api.pinterest.com/v5/pins")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "board_id": boardID,
            "media_source": [
                "source_type": "media_id",
                "media_id": mediaID
            ],
            "title": title,
            "description": description,
            "link": link.absoluteString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Pin creation failed: \(errorBody)")
        }
        
        struct PinResponse: Decodable {
            let id: String
            let link: String?
        }
        
        let pinResponse = try JSONDecoder().decode(PinResponse.self, from: data)
        return (pinResponse.id, pinResponse.link)
    }
}

// MARK: - Errors

enum PlatformError: Error, LocalizedError {
    case notConfigured
    case authenticationFailed
    case postFailed(String)
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Platform not configured"
        case .authenticationFailed:
            return "Authentication failed"
        case .postFailed(let reason):
            return "Post failed: \(reason)"
        case .notImplemented:
            return "Feature not yet implemented"
        }
    }
}
