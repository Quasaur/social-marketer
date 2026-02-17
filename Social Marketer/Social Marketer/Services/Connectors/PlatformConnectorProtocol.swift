//
//  PlatformConnectorProtocol.swift
//  SocialMarketer
//
//  Created by Automation on 2026-02-16.
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

/// Protocol for platforms that support video uploads
protocol VideoPlatformConnector: PlatformConnector {
    func postVideo(_ videoURL: URL, caption: String) async throws -> PostResult
}

/// Result of a platform post
struct PostResult {
    let success: Bool
    let postID: String?
    let postURL: URL?
    let error: Error?
}

/// Errors
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

// MARK: - Platform Credentials

struct PlatformCredentials: Codable {
    var twitter: TwitterCredentials?
    var instagram: InstagramCredentials?
    var linkedin: LinkedInCredentials?
    var facebook: FacebookCredentials?
    var pinterest: PinterestCredentials?
    var youtube: YouTubeCredentials?
    var tiktok: TikTokCredentials?

    struct TikTokCredentials: Codable {
        let accessToken: String
        let openID: String
    }
    
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
    
    struct YouTubeCredentials: Codable {
        let accessToken: String
        let refreshToken: String?
    }
}

// MARK: - Image Helper

extension NSImage {
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
