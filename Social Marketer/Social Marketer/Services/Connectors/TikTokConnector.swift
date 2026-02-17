//
//  TikTokConnector.swift
//  SocialMarketer
//
//  Created by Automation on 2026-02-16.
//

import Foundation
import AppKit

// MARK: - TikTok Connector

final class TikTokConnector: VideoPlatformConnector {
    let platformName = "TikTok"
    private let logger = Log.scheduler // Using scheduler log as no specific logger yet
    private var accessToken: String?
    private var openID: String?
    
    var isConfigured: Bool {
        get async {
            // Check for stored credentials
            if let creds = try? KeychainService.shared.retrieve(PlatformCredentials.TikTokCredentials.self, for: "tiktok_creds") {
                accessToken = creds.accessToken
                openID = creds.openID
                return true
            }
            return false
        }
    }
    
    func authenticate() async throws {
        // TikTok OAuth flow (simplified/placeholder)
        let config = try OAuthManager.shared.getConfig(for: "tiktok")
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "tiktok",
            config: config
        )
        try OAuthManager.shared.saveTokens(tokens, for: "tiktok")
        
        // Fetch User Info to get OpenID
        let openID = try await fetchUserInfo(token: tokens.accessToken)
        
        // Store using PlatformCredentials structure
        let creds = PlatformCredentials.TikTokCredentials(accessToken: tokens.accessToken, openID: openID)
        try KeychainService.shared.save(creds, for: "tiktok_creds")
        
        self.accessToken = tokens.accessToken
        self.openID = openID
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
         // TikTok supports photo mode, but primarily video.
         // For now, we'll throw an error or implement photo mode later.
         throw PlatformError.postFailed("TikTok connector currently only supports video.")
    }
    
    func postText(_ text: String) async throws -> PostResult {
        throw PlatformError.postFailed("TikTok does not support text-only posts.")
    }
    
    func postVideo(_ videoURL: URL, caption: String) async throws -> PostResult {
        guard let token = accessToken, let openID = openID else {
            throw PlatformError.notConfigured
        }
        
        logger.info("Initiating TikTok video upload...")
        
        // TikTok Direct Post / Content Posting API
        // 1. Initiate Resumable Upload
        let (uploadURL, uploadID) = try await initUpload(token: token, openID: openID)
        
        // 2. Upload Video
        try await uploadVideoFile(videoURL: videoURL, uploadURL: uploadURL)
        
        // 3. Finalize/Publish
        let postID = try await publishVideo(uploadID: uploadID, caption: caption, token: token, openID: openID)
        
        return PostResult(
            success: true,
            postID: postID,
            postURL: URL(string: "https://www.tiktok.com/@user/video/\(postID)"),
            error: nil
        )
    }
    
    // MARK: - Internal API Helpers (Placeholders/Rough Implementation)
    
    private func fetchUserInfo(token: String) async throws -> String {
        let url = URL(string: "https://open.tiktokapis.com/v2/user/info/?fields=open_id")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PlatformError.postFailed("Failed to fetch TikTok user info")
        }
        
        struct UserResponse: Decodable {
            struct Data: Decodable { let open_id: String }
            let data: Data
        }
        let resp = try JSONDecoder().decode(UserResponse.self, from: data)
        return resp.data.open_id
    }
    
    private func initUpload(token: String, openID: String) async throws -> (URL, String) {
        // Placeholder for TikTok Share API V2 / Content Posting initialization
        // Note: Real API requires complex chunked upload logic.
        // For CLI integration testing, we simulate success or use a known endpoint if available.
        // Assuming standard V2 endpoint structure.
        
        let url = URL(string: "https://open.tiktokapis.com/v2/post/publish/video/init/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "post_info": [
                "privacy_level": "PUBLIC_TO_EVERYONE",
                "disable_duet": false,
                "disable_comment": false,
                "disable_stitch": false,
                "video_cover_timestamp_ms": 1000
            ],
            "source_info": [
                "source": "FILE_UPLOAD",
                "video_size": 10000, 
                "chunk_size": 10000,
                "total_chunk_count": 1
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            // If failed, throw.
            throw PlatformError.postFailed("TikTok init upload failed")
        }
        
        struct InitResponse: Decodable {
            struct Data: Decodable {
                let upload_url: String
                let publish_id: String
            }
            let data: Data
        }
        let resp = try JSONDecoder().decode(InitResponse.self, from: data)
        guard let uURL = URL(string: resp.data.upload_url) else { throw PlatformError.postFailed("Invalid upload URL") }
        return (uURL, resp.data.publish_id)
    }
    
    private func uploadVideoFile(videoURL: URL, uploadURL: URL) async throws {
        // Simple PUT upload (for small videos, otherwise chunked is needed)
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        
        let data = try Data(contentsOf: videoURL)
        request.httpBody = data
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw PlatformError.postFailed("TikTok video binary upload failed")
        }
    }
    
    private func publishVideo(uploadID: String, caption: String, token: String, openID: String) async throws -> String {
        // Often init request already handles publishing or there's a verify step.
        // API varies by version. Returning uploadID as postID for now.
        return uploadID
    }
}
