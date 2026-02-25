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
            
            // Check TikTok media preference - skip if set to image (video only platform for now)
            if platformName == "TikTok" && platform.prefersImage {
                let skipMsg = "TikTok skipped - media preference set to image (video only)"
                logger.info("⏭️ \(skipMsg)")
                let log = PostLog(context: context, post: postRecord, platform: platform, error: skipMsg)
                postRecord.addToLogs(log)
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
            
            // Determine media type based on platform capabilities and preferences
            let platformPrefersVideo = platform.prefersVideo
            let videoAvailable = (videoURL != nil)
            let isVideoPlatform = (platformName == "YouTube" || platformName == "TikTok" || platformName == "Instagram")
            let disableVideoForPlatform = (platformName == "X (Twitter)" || platformName == "Facebook")
            
            do {
                var result: PostResult
                
                // Check if platform is set to video preference but video is not available
                if isVideoPlatform && platformPrefersVideo && !videoAvailable {
                    let errorMsg = "\(platformName) is set to video preference but no video is available. Video generation may have failed."
                    logger.error("❌ \(errorMsg)")
                    ErrorLog.shared.log(category: platformName, message: "Video post failed - no video available", detail: errorMsg)
                    let log = PostLog(context: context, post: postRecord, platform: platform, error: errorMsg)
                    postRecord.addToLogs(log)
                    failureCount += 1
                    errorMessages.append("\(platformName): \(errorMsg)")
                    continue
                }
                
                // For Instagram/TikTok: respect user preference; for others: auto-determine
                let useVideo: Bool
                if platformName == "Instagram" || platformName == "TikTok" {
                    useVideo = videoAvailable && platformPrefersVideo
                } else {
                    useVideo = videoAvailable && !disableVideoForPlatform
                }
                
                if useVideo && !disableVideoForPlatform, let videoPath = videoURL {
                    if let videoConnector = connector as? VideoPlatformConnector {
                        logger.info("🎥 Posting VIDEO to \(platformName)")
                        result = try await videoConnector.postVideo(videoPath, caption: caption)
                    } else {
                        // Platform prefers video but connector doesn't support video - this is an error
                        let errorMsg = "\(platformName) is set to video preference but video posting is not available. Check connector implementation."
                        logger.error("❌ \(errorMsg)")
                        ErrorLog.shared.log(category: platformName, message: "Video post failed", detail: errorMsg)
                        let log = PostLog(context: context, post: postRecord, platform: platform, error: errorMsg)
                        postRecord.addToLogs(log)
                        failureCount += 1
                        errorMessages.append("\(platformName): \(errorMsg)")
                        continue
                    }
                } else {
                    // IMAGE POST
                    if platformName == "YouTube" {
                        let errorMsg = "YouTube requires video but no video is available"
                        logger.error("❌ \(errorMsg)")
                        ErrorLog.shared.log(category: platformName, message: "Video post failed - no video", detail: errorMsg)
                        let log = PostLog(context: context, post: postRecord, platform: platform, error: errorMsg)
                        postRecord.addToLogs(log)
                        failureCount += 1
                        errorMessages.append("\(platformName): \(errorMsg)")
                        continue
                    }
                    
                    // TikTok/Instagram with image preference set
                    if (platformName == "TikTok" || platformName == "Instagram") && !platformPrefersVideo {
                        logger.info("🖼️ Posting IMAGE to \(platformName) (user preference)")
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
        
        // Track if any images or videos were successfully posted (for Content Library stats)
        var postedAnyImage = false
        var postedAnyVideo = false
        
        // Update post status
        let anySuccess = successCount > 0
        postRecord.postStatus = anySuccess ? .posted : .failed
        postRecord.postedDate = anySuccess ? Date() : nil
        
        // Update Post History if any platforms succeeded
        if anySuccess {
            updatePostHistory(
                post: postRecord,
                link: link,
                videoURL: videoURL,
                platforms: enabledPlatforms,
                context: context
            )
        }
        
        PersistenceController.shared.save()
        logger.info("Post results saved — \(anySuccess ? "at least one platform succeeded" : "all platforms failed")")
        
        return (successCount, failureCount, errorMessages)
    }
    
    // MARK: - Post History Tracking
    
    /// Update the Post History (CachedWisdomEntry) for posted content
    /// Creates new entry if not exists, updates stats if exists
    private func updatePostHistory(
        post: Post,
        link: URL,
        videoURL: URL?,
        platforms: [Platform],
        context: NSManagedObjectContext
    ) {
        let linkString = link.absoluteString
        
        // Find existing entry or create new one
        let historyEntry: CachedWisdomEntry
        if let existing = CachedWisdomEntry.findByLink(linkString, in: context) {
            historyEntry = existing
        } else {
            // Create new history entry from post data
            historyEntry = CachedWisdomEntry(context: context)
            historyEntry.id = UUID()
            historyEntry.linkString = linkString
            historyEntry.title = deriveTitle(from: post)
            historyEntry.content = post.content
            historyEntry.category = WisdomEntry.WisdomCategory.thought.rawValue
            historyEntry.fetchedAt = Date()
            historyEntry.usedCount = 0
            historyEntry.postedImageCount = 0
            historyEntry.postedVideoCount = 0
            logger.debug("Created new Post History entry: \(historyEntry.title ?? "Untitled")")
        }
        
        // Determine what media types were posted
        var postedImage = false
        var postedVideo = false
        
        for platform in platforms {
            let platformName = platform.name ?? ""
            let platformPrefersVideo = platform.prefersVideo
            let canUseVideo = (videoURL != nil) && (platformName == "YouTube" || platformName == "TikTok" || platformName == "Instagram")
            let disableVideoForPlatform = (platformName == "X (Twitter)" || platformName == "Facebook")
            
            let useVideo: Bool
            if platformName == "Instagram" || platformName == "TikTok" {
                useVideo = canUseVideo && platformPrefersVideo
            } else {
                useVideo = canUseVideo && !disableVideoForPlatform
            }
            
            if useVideo {
                postedVideo = true
            } else if !disableVideoForPlatform && platformName != "YouTube" {
                postedImage = true
            }
        }
        
        // Update counters
        if postedVideo {
            historyEntry.markPostedAsVideo()
        } else if postedImage {
            historyEntry.markPostedAsImage()
        } else {
            historyEntry.markAsUsed()
        }
        
        logger.debug("Updated Post History for: \(historyEntry.title ?? "Untitled") - Images: \(historyEntry.postedImageCount), Videos: \(historyEntry.postedVideoCount)")
    }
    
    /// Derive a title from post content (first line or first 60 chars)
    private func deriveTitle(from post: Post) -> String? {
        guard let content = post.content else { return nil }
        
        // Try to get first line
        let firstLine = content.split(separator: "\n", omittingEmptySubsequences: true).first
        if let line = firstLine {
            let title = String(line).trimmingCharacters(in: .whitespaces)
            // Limit to 60 chars for readability
            if title.count > 60 {
                return String(title.prefix(60)) + "..."
            }
            return title
        }
        
        // Fallback: first 60 chars of content
        if content.count > 60 {
            return String(content.prefix(60)) + "..."
        }
        return content
    }
}
