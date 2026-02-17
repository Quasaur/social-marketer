//
//  PlatformRouter.swift
//  SocialMarketer
//
//  Routes posts to the correct platform connectors and handles per-platform logic.
//  Extracted from PostScheduler.swift to follow Single Responsibility Principle.
//  Eliminates the duplicated posting loops that existed in postToAllPlatforms / postFromQueue.
//

import Foundation
import AppKit

/// Routes content to platform connectors with per-platform caption and media logic.
@MainActor
final class PlatformRouter {
    
    private let logger = Log.scheduler
    private let captionBuilder = CaptionBuilder()
    
    // MARK: - Connector Lookup
    
    /// Map a Core Data Platform to its API connector
    func connectorFor(_ platform: Platform) -> PlatformConnector? {
        guard let name = platform.name else { return nil }
        
        switch name {
        case "X (Twitter)":  return TwitterConnector()
        case "Instagram":    return InstagramConnector()
        case "LinkedIn":     return LinkedInConnector()
        case "Facebook":     return FacebookConnector()
        case "Pinterest":    return PinterestConnector()
        case "TikTok":       return TikTokConnector()
        case "YouTube":      return YouTubeConnector()
        default:
            logger.warning("Unknown platform: \(name)")
            return nil
        }
    }
    
    /// Map a Core Data Platform to its OAuth platform ID (used for token lookup)
    func oauthPlatformID(for platform: Platform) -> String? {
        switch platform.name {
        case "X (Twitter)": return "twitter"
        case "Instagram":   return "instagram"
        case "LinkedIn":    return "linkedin"
        case "Facebook":    return "facebook"
        case "Pinterest":   return "pinterest"
        case "TikTok":      return "tiktok"
        case "YouTube":     return "youtube"
        default:            return nil
        }
    }
    
    // MARK: - Unified Posting
    
    /// Post content to all enabled platforms with automatic caption and media selection.
    ///
    /// This is the single posting loop used by both scheduled posts and queue processing,
    /// eliminating the duplicate logic that previously existed.
    ///
    /// - Parameters:
    ///   - content: The text content / caption; for WisdomEntry posts, pass nil to auto-build from entry.
    ///   - entry: Optional WisdomEntry for auto-caption generation. Mutually exclusive with manual content.
    ///   - image: The post image (required for most platforms).
    ///   - imageURL: Saved image URL for the Post record.
    ///   - videoURL: Optional video URL for video-capable platforms.
    ///   - link: The link to include in the post.
    ///   - platforms: The platforms to post to. If nil, fetches all enabled platforms.
    ///   - post: An existing Post Core Data object. If nil, one is created.
    /// - Returns: Tuple of (successes, failures, error messages).
    @discardableResult
    func postToAll(
        content: String? = nil,
        entry: WisdomEntry? = nil,
        image: NSImage?,
        imageURL: URL?,
        videoURL: URL? = nil,
        link: URL,
        platforms: [Platform]? = nil,
        post: Post? = nil
    ) async -> (successes: Int, failures: Int, errors: [String]) {
        
        let context = PersistenceController.shared.viewContext
        let enabledPlatforms = platforms ?? Platform.fetchEnabled(in: context)
        
        guard !enabledPlatforms.isEmpty else {
            logger.warning("No platforms enabled.")
            return (0, 0, ["No platforms enabled"])
        }
        
        // Create or use provided Post record
        let postRecord = post ?? Post(context: context, content: content ?? entry?.content ?? "", imageURL: imageURL, link: link)
        if post == nil {
            postRecord.scheduledDate = Date()
        }
        
        var successCount = 0
        var failureCount = 0
        var errorMessages: [String] = []
        
        for platform in enabledPlatforms {
            let platformName = platform.name ?? "Unknown"
            logger.info("Posting to \(platformName)...")
            
            guard let connector = connectorFor(platform) else {
                let log = PostLog(context: context, post: postRecord, platform: platform, error: "No connector for \(platformName)")
                postRecord.addToLogs(log)
                continue
            }
            
            guard await connector.isConfigured else {
                let log = PostLog(context: context, post: postRecord, platform: platform, error: "Not configured — connect in Platforms settings")
                postRecord.addToLogs(log)
                logger.warning("\(platformName) not configured, skipping")
                continue
            }
            
            // Determine caption: auto-build from entry if available, otherwise use provided content
            let caption: String
            if let entry = entry {
                caption = (platformName == "X (Twitter)" || platformName == "LinkedIn")
                    ? captionBuilder.buildHashtagCaption(from: entry)
                    : captionBuilder.buildCaption(from: entry)
            } else {
                caption = content ?? ""
            }
            
            // Determine media type based on platform capabilities
            let useVideo = (videoURL != nil) && (platformName == "YouTube" || platformName == "TikTok" || platformName == "Instagram")
            let disableVideoForPlatform = (platformName == "X (Twitter)" || platformName == "Facebook")
            
            do {
                var result: PostResult
                
                if useVideo && !disableVideoForPlatform, let videoPath = videoURL {
                    if let videoConnector = connector as? VideoPlatformConnector {
                        logger.info("🎥 Posting VIDEO to \(platformName)")
                        result = try await videoConnector.postVideo(videoPath, caption: caption)
                    } else {
                        if platformName == "Instagram" {
                            logger.warning("Instagram video posting not strictly implemented, falling back to image")
                        }
                        guard let img = image else {
                            let log = PostLog(context: context, post: postRecord, platform: platform, error: "No image available")
                            postRecord.addToLogs(log)
                            logger.warning("Skipped \(platformName) — no image")
                            continue
                        }
                        result = try await connector.post(image: img, caption: caption, link: link)
                    }
                } else {
                    // IMAGE POST
                    if platformName == "YouTube" || platformName == "TikTok" {
                        logger.warning("Skipping \(platformName) - static images not supported/desired")
                        continue
                    }
                    
                    guard let img = image else {
                        let log = PostLog(context: context, post: postRecord, platform: platform, error: "No image available for post")
                        postRecord.addToLogs(log)
                        logger.warning("Skipped \(platformName) — no image")
                        continue
                    }
                    
                    result = try await connector.post(image: img, caption: caption, link: link)
                }
                
                if result.success {
                    let log = PostLog(context: context, post: postRecord, platform: platform, postID: result.postID, postURL: result.postURL)
                    postRecord.addToLogs(log)
                    platform.lastPostDate = Date()
                    successCount += 1
                    logger.info("✅ Posted to \(platformName): \(result.postID ?? "no ID")")
                } else {
                    let errorMsg = result.error?.localizedDescription ?? "Unknown error"
                    let log = PostLog(context: context, post: postRecord, platform: platform, error: errorMsg)
                    postRecord.addToLogs(log)
                    failureCount += 1
                    errorMessages.append("\(platformName): \(errorMsg)")
                    logger.error("❌ Failed to post to \(platformName): \(errorMsg)")
                    ErrorLog.shared.log(category: "Post", message: "Failed to post to \(platformName)", detail: errorMsg)
                }
            } catch {
                let log = PostLog(context: context, post: postRecord, platform: platform, error: error.localizedDescription)
                postRecord.addToLogs(log)
                failureCount += 1
                errorMessages.append("\(platformName): \(error.localizedDescription)")
                logger.error("❌ Error posting to \(platformName): \(error.localizedDescription)")
                ErrorLog.shared.log(category: "Post", message: "Error posting to \(platformName)", detail: error.localizedDescription)
            }
        }
        
        // Update post status
        let anySuccess = successCount > 0
        postRecord.postStatus = anySuccess ? .posted : .failed
        postRecord.postedDate = anySuccess ? Date() : nil
        
        PersistenceController.shared.save()
        logger.info("Post results saved — \(anySuccess ? "at least one platform succeeded" : "all platforms failed")")
        
        return (successCount, failureCount, errorMessages)
    }
}
