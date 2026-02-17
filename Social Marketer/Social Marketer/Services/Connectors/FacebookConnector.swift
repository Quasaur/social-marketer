//
//  FacebookConnector.swift
//  SocialMarketer
//
//  Created by Automation on 2026-02-16.
//

import Foundation
import AppKit

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
