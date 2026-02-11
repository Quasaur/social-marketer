//
//  PlatformConnector.swift
//  SocialMarketer
//
//  Protocol and implementations for social media platform APIs
//

import Foundation
import AppKit

/// Protocol for all platform connectors
protocol PlatformConnector {
    var platformName: String { get }
    var isConfigured: Bool { get async }
    
    func authenticate() async throws
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult
    func postText(_ text: String) async throws -> PostResult
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
    private let logger = Log.twitter
    private var signer: OAuth1Signer?
    
    var isConfigured: Bool {
        get async {
            do {
                let creds = try OAuthManager.shared.getTwitterOAuth1Credentials()
                signer = OAuth1Signer(
                    consumerKey: creds.consumerKey,
                    consumerSecret: creds.consumerSecret,
                    accessToken: creds.accessToken,
                    accessTokenSecret: creds.accessTokenSecret
                )
                return true
            } catch {
                return false
            }
        }
    }
    
    func authenticate() async throws {
        // OAuth 1.0a uses pre-generated tokens from the X Developer Portal
        // No browser flow needed — just verify credentials are stored
        if signer == nil {
            let creds = try OAuthManager.shared.getTwitterOAuth1Credentials()
            signer = OAuth1Signer(
                consumerKey: creds.consumerKey,
                consumerSecret: creds.consumerSecret,
                accessToken: creds.accessToken,
                accessTokenSecret: creds.accessTokenSecret
            )
        }
    }
    
    /// Post a text-only tweet (useful for testing the auth pipeline)
    func postText(_ text: String) async throws -> PostResult {
        guard let signer = signer else {
            throw PlatformError.notConfigured
        }
        
        let result = try await createTweet(text: text, mediaID: nil, signer: signer)
        
        logger.info("Text tweet posted successfully: \(result.id)")
        
        let postURL = URL(string: "https://x.com/i/status/\(result.id)")
        return PostResult(success: true, postID: result.id, postURL: postURL, error: nil)
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let signer = signer else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        // Step 1: Upload media using v1.1 media upload (OAuth 1.0a signed)
        let mediaID = try await uploadMedia(imageData: imageData, signer: signer)
        
        // Step 2: Create tweet with media
        let fullCaption = "\(caption)\n\n🔗 \(link.absoluteString)"
        let tweetResult = try await createTweet(text: fullCaption, mediaID: mediaID, signer: signer)
        
        logger.info("Tweet posted successfully: \(tweetResult.id)")
        
        let postURL = URL(string: "https://x.com/i/status/\(tweetResult.id)")
        return PostResult(success: true, postID: tweetResult.id, postURL: postURL, error: nil)
    }
    
    // MARK: - Media Upload (v1.1 with OAuth 1.0a signing)
    
    private func uploadMedia(imageData: Data, signer: OAuth1Signer) async throws -> String {
        let url = URL(string: "https://upload.twitter.com/1.1/media/upload.json")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Sign with OAuth 1.0a (multipart body is NOT included in signature base)
        let signedRequest = signer.sign(request)
        
        let (data, response) = try await URLSession.shared.data(for: signedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("Media upload failed (\(statusCode)): \(errorBody)")
            throw PlatformError.postFailed("Media upload failed (\(statusCode)): \(errorBody)")
        }
        
        struct MediaResponse: Decodable {
            let media_id_string: String
        }
        
        let mediaResponse = try JSONDecoder().decode(MediaResponse.self, from: data)
        logger.info("Media uploaded: \(mediaResponse.media_id_string)")
        return mediaResponse.media_id_string
    }
    
    // MARK: - Tweet Creation (v2 with OAuth 1.0a signing)
    
    private func createTweet(text: String, mediaID: String?, signer: OAuth1Signer) async throws -> (id: String, text: String) {
        let url = URL(string: "https://api.twitter.com/2/tweets")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = ["text": text]
        if let mediaID = mediaID {
            payload["media"] = ["media_ids": [mediaID]]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        // Sign with OAuth 1.0a (JSON body is NOT included in signature base)
        let signedRequest = signer.sign(request)
        
        let (data, response) = try await URLSession.shared.data(for: signedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("Tweet creation failed (\(statusCode)): \(errorBody)")
            throw PlatformError.postFailed("Tweet creation failed (\(statusCode)): \(errorBody)")
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
    private let logger = Log.instagram
    private var accessToken: String?
    private var businessAccountID: String?
    
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
            throw PlatformError.postFailed("Container creation failed: \(errorBody)")
        }
        
        struct ContainerResponse: Decodable {
            let id: String
        }
        
        let containerResponse = try JSONDecoder().decode(ContainerResponse.self, from: data)
        return containerResponse.id
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
    private let logger = Log.linkedin
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
    
    func setAccessToken(_ token: String) {
        self.accessToken = token
    }
    
    func setIdToken(_ idToken: String) {
        // Decode JWT to extract sub claim (person ID)
        if let personID = decodeJWTSub(idToken) {
            self.personURN = "urn:li:person:\(personID)"
            logger.info("Person URN from id_token: \(self.personURN ?? "nil")")
        }
    }
    
    private func decodeJWTSub(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        
        // Decode the payload (second part)
        var base64 = String(parts[1])
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        
        return sub
    }
    
    func authenticate() async throws {
        let config = try OAuthManager.shared.getConfig(for: "linkedin")
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "linkedin",
            config: config
        )
        try OAuthManager.shared.saveTokens(tokens, for: "linkedin")
        accessToken = tokens.accessToken
        
        // Extract person URN from id_token JWT
        if let idToken = tokens.idToken {
            setIdToken(idToken)
        }
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
    
    /// Post text-only content (no image) to LinkedIn
    func postText(_ text: String) async throws -> PostResult {
        guard let token = accessToken, let urn = personURN else {
            throw PlatformError.notConfigured
        }
        
        let postID = try await createTextPost(text: text, personURN: urn, token: token)
        
        logger.info("LinkedIn text post created: \(postID)")
        
        return PostResult(
            success: true,
            postID: postID,
            postURL: URL(string: "https://www.linkedin.com/feed/update/\(postID)"),
            error: nil
        )
    }
    
    private func createTextPost(text: String, personURN: String, token: String) async throws -> String {
        let url = URL(string: "https://api.linkedin.com/v2/posts")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2.0.0", forHTTPHeaderField: "LinkedIn-Version")
        
        let payload: [String: Any] = [
            "author": personURN,
            "commentary": text,
            "visibility": "PUBLIC",
            "distribution": [
                "feedDistribution": "MAIN_FEED",
                "targetEntities": [] as [[String: Any]],
                "thirdPartyDistributionChannels": [] as [[String: Any]]
            ],
            "lifecycleState": "PUBLISHED",
            "isReshareDisabledByAuthor": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlatformError.postFailed("No HTTP response")
        }
        
        guard httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Post creation failed (\(httpResponse.statusCode)): \(errorBody)")
        }
        
        // Post was created successfully (201)
        if let postID = httpResponse.value(forHTTPHeaderField: "x-restli-id") {
            return postID
        }
        
        // Some LinkedIn API versions don't return the header, but post was still created
        logger.info("Post created (201) but no x-restli-id header returned")
        return "created"
    }
}

// MARK: - Facebook Connector

/// Credentials for posting to a Facebook Page, stored in Keychain
struct FacebookPageCredentials: Codable {
    let pageID: String
    let pageName: String
    let pageAccessToken: String
}

final class FacebookConnector: PlatformConnector {
    let platformName = "Facebook"
    private let logger = Log.facebook
    private var accessToken: String?
    private var pageID: String?
    private var pageName: String?
    private var pageAccessToken: String?
    
    var isConfigured: Bool {
        get async {
            // Try to load page credentials from Keychain
            if pageID == nil || pageAccessToken == nil {
                loadPageCredentials()
            }
            return pageID != nil && pageAccessToken != nil
        }
    }
    
    /// The name of the connected Facebook Page (if any)
    var connectedPageName: String? {
        if pageName == nil { loadPageCredentials() }
        return pageName
    }
    
    func configure(pageID: String, pageAccessToken: String) {
        self.pageID = pageID
        self.pageAccessToken = pageAccessToken
    }
    
    func authenticate() async throws {
        let config = try OAuthManager.shared.getConfig(for: "facebook")
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "facebook",
            config: config
        )
        try OAuthManager.shared.saveTokens(tokens, for: "facebook")
        accessToken = tokens.accessToken
        
        // Automatically fetch Page Access Token after user authorization
        try await fetchPageAccessToken(userToken: tokens.accessToken)
    }
    
    /// Post a text-only message to the Facebook Page
    func postText(_ text: String) async throws -> PostResult {
        guard let pageToken = pageAccessToken, let page = pageID else {
            throw PlatformError.notConfigured
        }
        
        // Facebook Graph API - Post text to page feed
        var components = URLComponents(string: "https://graph.facebook.com/v24.0/\(page)/feed")!
        components.queryItems = [
            URLQueryItem(name: "message", value: text),
            URLQueryItem(name: "access_token", value: pageToken)
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Facebook text post failed: \(errorBody)")
            throw PlatformError.postFailed("Facebook text post failed: \(errorBody)")
        }
        
        struct PostResponse: Decodable {
            let id: String
        }
        
        let postResponse = try JSONDecoder().decode(PostResponse.self, from: data)
        logger.info("Facebook text post created: \(postResponse.id)")
        
        return PostResult(
            success: true,
            postID: postResponse.id,
            postURL: URL(string: "https://facebook.com/\(postResponse.id)"),
            error: nil
        )
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
        let url = URL(string: "https://graph.facebook.com/v24.0/\(page)/photos")!
        
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
    
    // MARK: - Page Access Token Exchange
    
    /// After user OAuth, call /me/accounts to get the Page Access Token
    private func fetchPageAccessToken(userToken: String) async throws {
        let url = URL(string: "https://graph.facebook.com/v24.0/me/accounts?access_token=\(userToken)")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to fetch pages: \(errorBody)")
            throw PlatformError.postFailed("Failed to fetch Facebook Pages: \(errorBody)")
        }
        
        // Log the raw response for debugging
        let rawResponse = String(data: data, encoding: .utf8) ?? "nil"
        logger.info("GET /me/accounts response: \(rawResponse)")
        
        struct PagesResponse: Decodable {
            struct Page: Decodable {
                let id: String
                let name: String
                let access_token: String
            }
            let data: [Page]
        }
        
        let pagesResponse = try JSONDecoder().decode(PagesResponse.self, from: data)
        
        guard let page = pagesResponse.data.first else {
            // Debug: check what permissions were actually granted
            let grantedPermissions = await checkGrantedPermissions(token: userToken)
            logger.error("No Facebook Pages found. Granted permissions: \(grantedPermissions)")
            throw PlatformError.postFailed("No Facebook Pages found. Granted permissions: \(grantedPermissions). Make sure pages_show_list and pages_manage_posts are approved.")
        }
        
        // Use the first page (or find "The Book of Wisdom" if multiple)
        let targetPage = pagesResponse.data.first(where: {
            $0.name.localizedCaseInsensitiveContains("wisdom") ||
            $0.name.localizedCaseInsensitiveContains("book")
        }) ?? page
        
        pageID = targetPage.id
        pageName = targetPage.name
        pageAccessToken = targetPage.access_token
        
        // Persist to Keychain
        let pageCreds = FacebookPageCredentials(
            pageID: targetPage.id,
            pageName: targetPage.name,
            pageAccessToken: targetPage.access_token
        )
        try KeychainService.shared.save(pageCreds, for: "facebook_page")
        
        logger.info("Facebook Page connected: \(targetPage.name) (ID: \(targetPage.id))")
    }
    
    /// Debug helper: check which permissions were actually granted by the user
    private func checkGrantedPermissions(token: String) async -> String {
        let url = URL(string: "https://graph.facebook.com/v24.0/me/permissions?access_token=\(token)")!
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let perms = json["data"] as? [[String: Any]] else {
            return "unable to check"
        }
        return perms.map { "\($0["permission"] ?? "?"): \($0["status"] ?? "?")" }.joined(separator: ", ")
    }
    
    /// Load page credentials from Keychain
    private func loadPageCredentials() {
        guard let pageCreds = try? KeychainService.shared.retrieve(FacebookPageCredentials.self, for: "facebook_page") else {
            return
        }
        pageID = pageCreds.pageID
        pageName = pageCreds.pageName
        pageAccessToken = pageCreds.pageAccessToken
    }
}

// MARK: - Pinterest Connector

struct PinterestCredentials: Codable {
    let boardID: String
    let boardName: String
}

final class PinterestConnector: PlatformConnector {
    let platformName = "Pinterest"
    private let logger = Log.pinterest
    private var accessToken: String?
    private var boardID: String?
    private var boardName: String?
    
    var isConfigured: Bool {
        get async {
            // Load cached credentials
            if let cached = try? KeychainService.shared.retrieve(PinterestCredentials.self, for: "pinterest_board") {
                boardID = cached.boardID
                boardName = cached.boardName
            }
            
            do {
                let tokens = try OAuthManager.shared.getTokens(for: "pinterest")
                accessToken = tokens.accessToken
                return boardID != nil
            } catch {
                return false
            }
        }
    }
    
    func authenticate() async throws {
        let config = try OAuthManager.shared.getConfig(for: "pinterest")
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "pinterest",
            config: config
        )
        try OAuthManager.shared.saveTokens(tokens, for: "pinterest")
        accessToken = tokens.accessToken
        
        // Auto-discover the user's first board
        try await fetchFirstBoard(token: tokens.accessToken)
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let token = accessToken, let board = boardID else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        // Pinterest v5 API supports inline base64 image in pin creation
        let base64Image = imageData.base64EncodedString()
        
        let pin = try await createPinWithImage(
            base64Image: base64Image,
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
    
    func postText(_ text: String) async throws -> PostResult {
        // Pinterest requires an image for all pins
        throw PlatformError.postFailed("Pinterest requires an image. Text-only posts are not supported.")
    }
    
    // MARK: - Board Discovery
    
    private func fetchFirstBoard(token: String) async throws {
        let url = URL(string: "https://api.pinterest.com/v5/boards")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to fetch boards: \(errorBody)")
            throw PlatformError.postFailed("Failed to fetch Pinterest boards: \(errorBody)")
        }
        
        struct BoardsResponse: Decodable {
            struct Board: Decodable {
                let id: String
                let name: String
            }
            let items: [Board]
        }
        
        let boardsResponse = try JSONDecoder().decode(BoardsResponse.self, from: data)
        
        guard let firstBoard = boardsResponse.items.first else {
            throw PlatformError.postFailed("No Pinterest boards found. Create a board on Pinterest first.")
        }
        
        boardID = firstBoard.id
        boardName = firstBoard.name
        
        // Persist to Keychain
        let creds = PinterestCredentials(boardID: firstBoard.id, boardName: firstBoard.name)
        try KeychainService.shared.save(creds, for: "pinterest_board")
        
        logger.info("Pinterest board connected: \(firstBoard.name) (ID: \(firstBoard.id))")
    }
    
    // MARK: - Pin Creation
    
    private func createPinWithImage(base64Image: String, boardID: String, title: String, description: String, link: URL, token: String) async throws -> (id: String, url: String?) {
        let url = URL(string: "https://api.pinterest.com/v5/pins")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "board_id": boardID,
            "media_source": [
                "source_type": "image_base64",
                "content_type": "image/jpeg",
                "data": base64Image
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
