//
//  PlatformType.swift
//  SocialMarketer
//
//  Type-safe platform enumeration
//

import Foundation

/// Type-safe enumeration of all supported social media platforms
enum PlatformType: String, CaseIterable, Identifiable, Codable {
    case twitter = "X (Twitter)"
    case instagram = "Instagram"
    case linkedIn = "LinkedIn"
    case facebook = "Facebook"
    case pinterest = "Pinterest"
    case tikTok = "TikTok"
    case youTube = "YouTube"
    case substack = "Substack"
    
    var id: String { rawValue }
    
    /// Internal identifier used for OAuth and storage
    var identifier: String {
        switch self {
        case .twitter: return "twitter"
        case .instagram: return "instagram"
        case .linkedIn: return "linkedin"
        case .facebook: return "facebook"
        case .pinterest: return "pinterest"
        case .tikTok: return "tiktok"
        case .youTube: return "youtube"
        case .substack: return "substack"
        }
    }
    
    /// OAuth platform ID (may differ from identifier in some cases)
    var oauthPlatformID: String { identifier }
    
    /// Preferred media type for this platform
    var preferredMediaType: MediaType {
        switch self {
        case .youTube, .tikTok:
            return .video
        case .instagram:
            return .video  // Can do both, but prefer video
        default:
            return .image
        }
    }
    
    /// Whether this platform supports video uploads
    var supportsVideo: Bool {
        switch self {
        case .youTube, .tikTok, .instagram:
            return true
        default:
            return false
        }
    }
    
    /// Whether this platform supports image uploads
    var supportsImage: Bool {
        switch self {
        case .youTube:
            return false  // YouTube requires video
        default:
            return true
        }
    }
    
    /// Whether this platform requires OAuth 1.0a (vs OAuth 2.0)
    var usesOAuth1: Bool {
        self == .twitter
    }
    
    /// Logger category for this platform
    var loggerCategory: String {
        identifier
    }
    
    /// Display icon name (SF Symbol)
    var iconName: String {
        switch self {
        case .twitter: return "bird.fill"
        case .instagram: return "camera.fill"
        case .linkedIn: return "briefcase.fill"
        case .facebook: return "f.square.fill"
        case .pinterest: return "pin.fill"
        case .tikTok: return "music.note"
        case .youTube: return "play.rectangle.fill"
        case .substack: return "newspaper.fill"
        }
    }
}

// MARK: - Media Type

enum MediaType: String, Codable {
    case video, image, both
}

// MARK: - Platform Matching

extension PlatformType {
    
    /// Initialize from a platform identifier string
    /// - Parameter identifier: The platform identifier (e.g., "twitter", "linkedin")
    init?(identifier: String) {
        switch identifier.lowercased() {
        case "twitter", "x": self = .twitter
        case "instagram": self = .instagram
        case "linkedin": self = .linkedIn
        case "facebook": self = .facebook
        case "pinterest": self = .pinterest
        case "tiktok": self = .tikTok
        case "youtube": self = .youTube
        case "substack": self = .substack
        default: return nil
        }
    }
    
    /// Initialize from a platform name
    /// - Parameter name: The platform display name (e.g., "X (Twitter)", "LinkedIn")
    init?(name: String) {
        if let type = PlatformType.allCases.first(where: { $0.rawValue == name }) {
            self = type
        } else if let type = PlatformType(identifier: name) {
            self = type
        } else {
            return nil
        }
    }
}

// MARK: - Platform Groups

extension PlatformType {
    
    /// Platforms that support video content
    static var videoPlatforms: [PlatformType] {
        allCases.filter { $0.supportsVideo }
    }
    
    /// Platforms that use OAuth 2.0
    static var oauth2Platforms: [PlatformType] {
        allCases.filter { !$0.usesOAuth1 }
    }
    
    /// Tier 1 platforms (fully implemented)
    static var tier1: [PlatformType] {
        [.twitter, .linkedIn, .facebook, .instagram, .pinterest, .youTube]
    }
}
