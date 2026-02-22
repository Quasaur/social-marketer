//
//  Configuration.swift
//  SocialMarketer
//
//  Centralized configuration constants for the application.
//  Replaces scattered hardcoded values throughout the codebase.
//

import Foundation
import AppKit

/// Centralized application configuration
/// 
/// This enum provides a single source of truth for all configurable values
/// including URLs, timeouts, file paths, and UserDefaults keys.
/// 
/// Usage:
/// ```swift
/// let timeout = AppConfiguration.Timeouts.videoGeneration
/// let url = AppConfiguration.URLs.wisdomBook
/// ```
public enum AppConfiguration {
    
    // MARK: - URLs
    
    public enum URLs {
        /// Main website domain
        public static let wisdomBookDomain = "wisdombook.life"
        
        /// Full website URL with https
        public static let wisdomBook = "https://www.wisdombook.life"
        
        /// Social Effects API base URL (configurable via UserDefaults for development)
        public static var socialEffects: String {
            UserDefaults.standard.string(forKey: Keys.socialEffectsBaseURL)
            ?? "http://localhost:5390"
        }
        
        /// Social Effects health endpoint
        public static var socialEffectsHealth: String {
            "\(socialEffects)/health"
        }
        
        /// Social Effects generate endpoint
        public static var socialEffectsGenerate: String {
            "\(socialEffects)/generate"
        }
    }
    
    // MARK: - File Paths
    
    public enum Paths {
        /// Social Effects binary location
        /// Defaults to ~/Developer/social-effects but can be customized
        public static var socialEffectsBinary: String {
            UserDefaults.standard.string(forKey: Keys.socialEffectsBinaryPath)
            ?? "/Users/\(NSUserName())/Developer/social-effects/.build/debug/SocialEffects"
        }
        
        /// Video storage directory
        /// Defaults to external drive if available, falls back to app support
        public static var videoStorage: String {
            UserDefaults.standard.string(forKey: Keys.videoStoragePath)
            ?? "/Volumes/My Passport/social-media-content/social-effects/video/api/"
        }
        
        /// Test video storage directory (sibling to production)
        public static var videoTestStorage: String {
            (videoStorage as NSString).deletingLastPathComponent + "/test/"
        }
        
        /// App Group container for shared data
        public static let appGroupIdentifier = "group.com.wisdombook.SocialMarketer"
        
        /// Core Data store directory
        public static var coreDataStore: URL? {
            FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
                .appendingPathComponent("SocialMarketer.sqlite")
        }
    }
    
    // MARK: - Timeouts
    
    public enum Timeouts {
        /// Video generation timeout (8 minutes)
        public static let videoGeneration: TimeInterval = 480
        
        /// Health check probe timeout
        public static let healthCheck: TimeInterval = 8
        
        /// Social Effects startup timeout
        public static let socialEffectsStartup: TimeInterval = 5
        
        /// API request timeout
        public static let apiRequest: TimeInterval = 30
        
        /// OAuth authentication timeout
        public static let oauth: TimeInterval = 120
        
        /// Server shutdown wait timeout
        public static let shutdown: TimeInterval = 5
    }
    
    // MARK: - Limits
    
    public enum Limits {
        /// Maximum number of entries in error log
        public static let maxErrorLogEntries = 100
        
        /// Maximum video generation retry attempts
        public static let maxVideoRetries = 2
        
        /// Maximum characters for platform posts (conservative)
        public static let maxPostLength = 2000
        
        /// Maximum upload size in bytes (100MB)
        public static let maxUploadSize = 100 * 1024 * 1024
    }
    
    // MARK: - Intervals
    
    public enum Intervals {
        /// Interval between introductory posts (90 days)
        public static let introRepost: TimeInterval = 90 * 24 * 60 * 60
        
        /// RSS feed check interval (15 minutes)
        public static let rssCheck: TimeInterval = 15 * 60
        
        /// Health check poll interval (30 seconds)
        public static let healthCheckPoll: TimeInterval = 30
    }
    
    // MARK: - UserDefaults Keys
    
    public enum Keys {
        // Border/Graphics
        public static let lastBorderStyle = "lastUsedBorderStyle"
        
        // App State
        public static let hasLaunchedBefore = "hasLaunchedBefore"
        public static let lastIntroPostDate = "lastIntroPostDate"
        
        // Configuration Overrides
        public static let videoStoragePath = "videoStoragePath"
        public static let socialEffectsBinaryPath = "socialEffectsBinaryPath"
        public static let socialEffectsBaseURL = "socialEffectsBaseURL"
        
        // Feed URLs
        public static let dailyFeedURL = "dailyFeedURL"
        public static let thoughtsFeedURL = "thoughtsFeedURL"
    }
    
    // MARK: - RSS Feeds
    
    public enum Feeds {
        /// Daily wisdom feed URL
        public static let daily = "https://wisdombook.life/feed/daily.xml"
        
        /// Thoughts feed URL  
        public static let thoughts = "https://wisdombook.life/feed/thoughts.xml"
        
        /// All configured feeds
        public static let all = [daily, thoughts]
    }
    
    // MARK: - Graphics
    
    public enum Graphics {
        /// Default window size
        public static let defaultWindowSize = CGSize(width: 800, height: 600)
        
        /// Quote graphic output size
        public static let quoteImageSize = CGSize(width: 1080, height: 1080)
        
        /// Video output dimensions (vertical format)
        public static let videoSize = CGSize(width: 1080, height: 1920)
        
        /// Border inset from edges
        public static let borderInset: CGFloat = 30
        
        /// Text margin from border
        public static let textMargin: CGFloat = 80
        
        /// Title margin from top
        public static let titleMargin: CGFloat = 160
    }
    
    // MARK: - Date Formats
    
    public enum DateFormats {
        /// RSS pubDate format
        public static let rss = "E, dd MMM yyyy HH:mm:ss zzz"
        
        /// ISO 8601 format
        public static let iso8601 = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        /// Display format
        public static let display = "MMM d, yyyy"
    }
    
    // MARK: - Keychain
    
    public enum Keychain {
        /// Service identifier for keychain items
        public static let serviceIdentifier = "com.wisdombook.socialmarketer"
        
        /// Account keys for different credential types
        public enum Accounts {
            public static let twitter = "twitter_credentials"
            public static let linkedIn = "linkedin_credentials"
            public static let facebook = "facebook_credentials"
            public static let instagram = "instagram_credentials"
            public static let pinterest = "pinterest_credentials"
            public static let tikTok = "tiktok_credentials"
            public static let youTube = "youtube_credentials"
        }
    }
    
    // MARK: - Regex Patterns
    
    public enum Patterns {
        /// Extract "Today's Wisdom" prefix from content
        public static let todaysWisdom = "^Today[''']s Wisdom:\\s*"
        
        /// Reference citation pattern (e.g., "(Proverbs 1:1)")
        public static let reference = "\\([^)]+\\)"
        
        /// URL pattern for validation
        public static let url = "https?://[a-zA-Z0-9\\-\\.]+\\.[a-zA-Z]{2,}(/[^\\s]*)?"
    }
    
    // MARK: - URL Schemes
    
    public enum URLSchemes {
        /// App's custom URL scheme
        public static let app = "socialmarketer"
        
        /// OAuth callback URL
        public static var oauthCallback: String {
            "\(app)://oauth/callback"
        }
        
        /// Introduction post trigger
        public static var introduction: String {
            "\(app)://introduction"
        }
    }
}

// MARK: - Convenience Extensions

public extension AppConfiguration.Graphics {
    /// Standard line widths for drawing
    enum LineWidth: CGFloat {
        case thin = 1.0
        case light = 1.5
        case medium = 2.0
        case thick = 2.5
        case heavy = 3.0
        case extraThick = 4.0
    }
    
    /// Standard font sizes for quote graphics
    enum FontSize: CGFloat {
        case caption = 16
        case body = 24
        case title = 36
        case largeTitle = 48
    }
}

public extension AppConfiguration.Limits {
    /// Check if data size is within upload limits
    static func isValidUploadSize(_ size: Int) -> Bool {
        size <= maxUploadSize
    }
    
    /// Check if content length is within platform limits
    static func isValidPostLength(_ length: Int) -> Bool {
        length <= maxPostLength
    }
}
