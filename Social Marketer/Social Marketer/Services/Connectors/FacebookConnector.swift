//
//  FacebookConnector.swift
//  SocialMarketer
//
//  Refactored to use BasePlatformConnector and MultipartFormBuilder.
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

final class FacebookConnector: BasePlatformConnector, PlatformConnector {
    
    override var platformName: String { "Facebook" }
    
    private var accessToken: String?
    private var pageID: String?
    private var pageName: String?
    private var pageAccessToken: String?
    
    var isConfigured: Bool {
        get async {
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
        let tokens = try await performOAuthAuthentication()
        accessToken = tokens.accessToken
        
        // Automatically fetch Page Access Token after user authorization
        try await fetchPageAccessToken(userToken: tokens.accessToken)
    }
    
    /// Post a text-only message to the Facebook Page
    func postText(_ text: String) async throws -> PostResult {
        guard let pageToken = pageAccessToken, let page = pageID else {
            throw PlatformError.notConfigured
        }
        
        var components = URLComponents(string: "https://graph.facebook.com/v24.0/\(page)/feed")!
        components.queryItems = [
            URLQueryItem(name: "message", value: text),
            URLQueryItem(name: "access_token", value: pageToken)
        ]
        
        let request = postRequest(url: components.url!)
        let postResponse = try await performJSONRequest(request, decoding: PostResponse.self)
        
        logInfo("Facebook text post created: \(postResponse.id)")
        
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
        
        // Build multipart form using MultipartFormBuilder
        var builder = MultipartFormBuilder()
        builder.addField(name: "access_token", value: pageToken)
        builder.addField(name: "message", value: fullCaption)
        builder.addJPEGImage(name: "source", data: imageData)
        
        let (body, contentType) = builder.build()
        
        let url = URL(string: "https://graph.facebook.com/v24.0/\(page)/photos")!
        let request = postRequest(url: url, body: body, contentType: contentType)
        
        let photoResponse = try await performJSONRequest(request, decoding: PhotoResponse.self)
        
        logInfo("Facebook photo posted: \(photoResponse.id)")
        
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
        
        let request = getRequest(url: url)
        let pagesResponse = try await performJSONRequest(request, decoding: PagesResponse.self)
        
        guard let page = pagesResponse.data.first else {
            let grantedPermissions = await checkGrantedPermissions(token: userToken)
            logError("No Facebook Pages found", detail: "Granted permissions: \(grantedPermissions)")
            throw PlatformError.postFailed("No Facebook Pages found. Granted permissions: \(grantedPermissions)")
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
        
        logInfo("Facebook Page connected: \(targetPage.name) (ID: \(targetPage.id))")
    }
    
    /// Debug helper: check which permissions were actually granted by the user
    private func checkGrantedPermissions(token: String) async -> String {
        let url = URL(string: "https://graph.facebook.com/v24.0/me/permissions?access_token=\(token)")!
        guard let (data, _) = try? await session.data(from: url),
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
    
    // MARK: - Response Types
    
    private struct PostResponse: Decodable {
        let id: String
    }
    
    private struct PhotoResponse: Decodable {
        let id: String
        let post_id: String?
    }
    
    private struct PagesResponse: Decodable {
        struct Page: Decodable {
            let id: String
            let name: String
            let access_token: String
        }
        let data: [Page]
    }
}
