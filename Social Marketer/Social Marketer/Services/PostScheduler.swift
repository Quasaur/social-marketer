//
//  PostScheduler.swift
//  SocialMarketer
//
//  Orchestrates scheduled and manual posting across platforms.
//  Delegates to focused, single-responsibility collaborators:
//    • LaunchdManager  — launchd agent lifecycle
//    • VideoGenerator  — SocialEffects CLI invocation
//    • CaptionBuilder  — caption / hashtag generation
//    • PlatformRouter  — connector dispatch & posting loop
//

import Foundation
import AppKit

/// Orchestrates scheduled posting across platforms.
/// Thin facade — heavy lifting lives in LaunchdManager, VideoGenerator,
/// CaptionBuilder, and PlatformRouter.
@MainActor
final class PostScheduler {
    
    private let logger = Log.scheduler
    private let googleIndexing = GoogleIndexingConnector()
    private let launchd = LaunchdManager()
    private let videoGen = VideoGenerator()
    private let router = PlatformRouter()
    private var isRunning = false
    
    // MARK: - Schedule Passthrough (preserves call-site compatibility)
    
    static var scheduledHour: Int {
        get { LaunchdManager.scheduledHour }
        set { LaunchdManager.scheduledHour = newValue }
    }
    
    static var scheduledMinute: Int {
        get { LaunchdManager.scheduledMinute }
        set { LaunchdManager.scheduledMinute = newValue }
    }
    
    // MARK: - launchd Delegation
    
    var isLaunchAgentInstalled: Bool { launchd.isLaunchAgentInstalled }
    func ensureLaunchAgentCurrent() { launchd.ensureLaunchAgentCurrent() }
    func installLaunchAgent() throws { try launchd.installLaunchAgent() }
    func uninstallLaunchAgent() throws { try launchd.uninstallLaunchAgent() }
    
    // MARK: - Video Discovery
    
    /// Directory where Social Effects saves generated videos
    private let videoStorageDir = "/Volumes/My Passport/social-media-content/social-effects/video/api/"
    
    /// Looks for an existing video file matching the given title
    /// - Parameter title: The wisdom entry title to match
    /// - Returns: URL to existing video if found, nil otherwise
    func findExistingVideo(for title: String) -> URL? {
        let fm = FileManager.default
        
        // Ensure directory exists
        guard fm.fileExists(atPath: videoStorageDir) else {
            logger.debug("Video directory not found: \(self.videoStorageDir)")
            return nil
        }
        
        // Get list of video files
        guard let files = try? fm.contentsOfDirectory(atPath: videoStorageDir) else {
            return nil
        }
        
        // Sanitize title for matching (similar to VideoGenerator.sanitizeTitle)
        let sanitizedTitle = title
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .lowercased()
        
        // Look for matching video file
        for file in files where file.hasSuffix(".mp4") {
            let lowerFile = file.lowercased()
            
            // Match pattern: thought-{TITLE}-{TIMESTAMP}.mp4 or passage-{TITLE}-{TIMESTAMP}.mp4
            if lowerFile.contains(sanitizedTitle) ||
               sanitizedTitle.contains(lowerFile.replacingOccurrences(of: "thought-", with: "")
                   .replacingOccurrences(of: "passage-", with: "")
                   .replacingOccurrences(of: "_", with: " ")
                   .replacingOccurrences(of: "-", with: " ")
                   .prefix(40)) {
                let videoURL = URL(fileURLWithPath: videoStorageDir + file)
                logger.info("✅ Found existing video: \(file)")
                return videoURL
            }
        }
        
        return nil
    }
    
    /// Gets or creates a video for the given wisdom entry
    /// Checks for existing video first, generates new one only if needed
    /// - Parameter entry: The wisdom entry to get video for
    /// - Returns: URL to video file (existing or newly generated)
    func getOrCreateVideo(for entry: WisdomEntry) async throws -> URL? {
        // First, check if an existing video matches this content
        if let existingURL = findExistingVideo(for: entry.title) {
            logger.info("🎬 Using existing video for: \(entry.title)")
            return existingURL
        }
        
        // No existing video found - generate new one
        logger.info("🎬 No existing video found, generating new video for: \(entry.title)")
        return try await videoGen.generateVideo(entry: entry)
    }
    
    // MARK: - Scheduled Post Execution
    
    /// Check if a platform has already been posted to today
    private func hasPostedToday(platform: Platform) -> Bool {
        guard let lastPostDate = platform.lastPostDate else { return false }
        
        let calendar = Calendar.current
        return calendar.isDate(lastPostDate, inSameDayAs: Date())
    }
    
    /// Execute scheduled posting (called by launchd or manually)
    func executeScheduledPost() async {
        logger.info("Executing scheduled post...")
        
        // Diagnostic: log platform state (when Debug Mode enabled)
        let context = PersistenceController.shared.viewContext
        let allPlatforms = (try? context.fetch(Platform.fetchRequest())) ?? []
        let enabledPlatforms = allPlatforms.filter { $0.isEnabled }
        if Log.isDebugMode {
            Log.debug("Platforms: \(allPlatforms.count) total, \(enabledPlatforms.count) enabled", category: "Scheduler")
            for p in allPlatforms {
                Log.debug("  - \(p.name ?? "?") enabled=\(p.isEnabled) apiType=\(p.apiType ?? "?")", category: "Scheduler")
            }
        }
        
        // Filter out platforms that have already been posted to today
        let platformsToPost = enabledPlatforms.filter { platform in
            let alreadyPosted = hasPostedToday(platform: platform)
            if alreadyPosted, let name = platform.name {
                logger.info("⏭️ Skipping \(name) — already posted today")
            }
            return !alreadyPosted
        }
        
        guard !platformsToPost.isEmpty else {
            logger.info("All enabled platforms have already been posted to today — skipping")
            return
        }
        
        if platformsToPost.count < enabledPlatforms.count {
            logger.info("Posting to \(platformsToPost.count) of \(enabledPlatforms.count) enabled platforms (others already posted today)")
        }
        
        // Check if introductory post is due (every 90 days)
        await postIntroductoryIfDue()
        
        do {
            // 1. Fetch daily wisdom
            let rssParser = RSSParser()
            guard let entry = try await rssParser.fetchDaily() else {
                logger.warning("No daily wisdom entry available")
                return
            }
            
            logger.info("Fetched wisdom: \(entry.title)")
            
            // 2. Generate quote graphic
            let generator = QuoteGraphicGenerator()
            guard let image = generator.generate(from: entry) else {
                logger.error("Failed to generate quote graphic")
                return
            }
            
            // 3. Save to temp directory
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("wisdom_\(Date().timeIntervalSince1970).png")
            try generator.save(image, to: tempURL)
            
            logger.info("Quote graphic saved to \(tempURL.path)")
            
            // 3a. Get or create video (checks for existing first)
            let videoURL = try await getOrCreateVideo(for: entry)
            
            // 4. Post to enabled platforms (excluding those already posted today)
            await router.postToAll(entry: entry, image: image, imageURL: tempURL, videoURL: videoURL, link: entry.link, platforms: platformsToPost)
            
            // 5. Ping Google Search Console
            await pingGoogle(url: entry.link)
            
            // 6. Cleanup - only remove temp image, preserve video files
            try? FileManager.default.removeItem(at: tempURL)
            // Note: We don't delete videoURL because it might be a reused existing video
            
            logger.info("Scheduled posting complete")
            
        } catch {
            logger.error("Scheduled posting failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Introductory Post (90-Day Cycle)
    
    /// Interval between introductory post reposts (90 days)
    private static let introRepostInterval: TimeInterval = 90 * 24 * 60 * 60
    
    /// Check and post the introductory post if 90+ days have elapsed
    private func postIntroductoryIfDue() async {
        let context = PersistenceController.shared.viewContext
        let introLink = "socialmarketer://introduction"
        
        guard let introEntry = CachedWisdomEntry.findByLink(introLink, in: context) else {
            logger.debug("No introductory post found — skipping 90-day check")
            return
        }
        
        // Check if it's due: never posted, or last posted ≥90 days ago
        let isDue: Bool
        if let lastUsed = introEntry.lastUsedAt {
            isDue = Date().timeIntervalSince(lastUsed) >= Self.introRepostInterval
            if !isDue {
                let daysRemaining = Int((Self.introRepostInterval - Date().timeIntervalSince(lastUsed)) / (24 * 60 * 60))
                logger.debug("Introductory post not due — \(daysRemaining) days remaining")
            }
        } else {
            isDue = true // Never posted
        }
        
        guard isDue else { return }
        
        logger.notice("📢 Introductory post is due — posting to all platforms")
        
        let caption = introEntry.content ?? ""
        let link = URL(string: "https://www.wisdombook.life")!
        
        let enabledPlatforms = Platform.fetchEnabled(in: context)
        guard !enabledPlatforms.isEmpty else {
            logger.warning("No platforms enabled for introductory post")
            return
        }
        
        // Create a Post record for the intro
        let post = Post(context: context, content: caption, imageURL: nil, link: link)
        post.scheduledDate = Date()
        
        var anySuccess = false
        
        for platform in enabledPlatforms {
            let platformName = platform.name ?? "Unknown"
            
            guard let connector = router.connectorFor(platform) else { continue }
            guard await connector.isConfigured else {
                logger.warning("\(platformName) not configured for intro post, skipping")
                continue
            }
            
            do {
                // Post as text (intro post is text-only, no graphic)
                let result = try await connector.postText(caption)
                
                if result.success {
                    let log = PostLog(context: context, post: post, platform: platform, postID: result.postID, postURL: result.postURL)
                    post.addToLogs(log)
                    anySuccess = true
                    logger.info("✅ Intro posted to \(platformName)")
                } else {
                    let errorMsg = result.error?.localizedDescription ?? "Unknown error"
                    let log = PostLog(context: context, post: post, platform: platform, error: errorMsg)
                    post.addToLogs(log)
                    logger.error("❌ Intro post failed on \(platformName): \(errorMsg)")
                }
            } catch {
                let log = PostLog(context: context, post: post, platform: platform, error: error.localizedDescription)
                post.addToLogs(log)
                logger.error("❌ Intro post error on \(platformName): \(error.localizedDescription)")
            }
        }
        
        if anySuccess {
            post.postStatus = .posted
            post.postedDate = Date()
            introEntry.markAsUsed()
            logger.notice("📢 Introductory post completed — next due in 90 days")
        } else {
            post.postStatus = .failed
        }
        
        PersistenceController.shared.save()
    }
    
    // MARK: - Manual Thought Posting
    
    /// Post a user-composed Thought to all enabled platforms.
    /// Called from GraphicPreviewView when "Post Now" is tapped.
    /// Returns (successes, failures, error descriptions) so the UI can display accurate results.
    func postManualThought(image: NSImage, caption: String, link: URL) async -> (successes: Int, failures: Int, errors: [String]) {
        logger.info("🖊️ Manual Thought post initiated")
        
        // Save image to app support for the Post record
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let postDir = appSupport.appendingPathComponent("SocialMarketer/ManualThoughts", isDirectory: true)
        try? FileManager.default.createDirectory(at: postDir, withIntermediateDirectories: true)
        let imageURL = postDir.appendingPathComponent("thought_\(Date().timeIntervalSince1970).png")
        
        let generator = QuoteGraphicGenerator()
        do {
            try generator.save(image, to: imageURL)
        } catch {
            logger.error("Failed to save manual thought image: \(error.localizedDescription)")
            return (0, 0, ["Failed to save image: \(error.localizedDescription)"])
        }
        
        let result = await router.postToAll(content: caption, image: image, imageURL: imageURL, link: link)
        
        // Ping Google if any platform succeeded
        if result.successes > 0 {
            await pingGoogle(url: link)
        }
        
        return result
    }
    
    // MARK: - Queue Processing
    
    /// Process all pending posts whose scheduled date has arrived
    func processQueue() async {
        let context = PersistenceController.shared.viewContext
        let pendingPosts = Post.fetchPending(in: context)
        
        let now = Date()
        let duePosts = pendingPosts.filter { post in
            guard let scheduledDate = post.scheduledDate else { return false }
            return scheduledDate <= now
        }
        
        if duePosts.isEmpty {
            logger.info("No due posts in queue")
            return
        }
        
        logger.info("Processing \(duePosts.count) due post(s)")
        
        let enabledPlatforms = Platform.fetchEnabled(in: context)
        
        guard !enabledPlatforms.isEmpty else {
            logger.warning("No platforms enabled")
            return
        }
        
        for post in duePosts {
            await postFromQueue(post, to: enabledPlatforms)
        }
    }
    
    /// Post a single queued post to all enabled platforms — delegates to PlatformRouter
    /// Checks for existing video before generating new one
    private func postFromQueue(_ post: Post, to platforms: [Platform]) async {
        guard let content = post.content else {
            logger.warning("Skipping post with no content")
            post.postStatus = .failed
            PersistenceController.shared.save()
            return
        }
        
        // Load image if available
        var image: NSImage?
        if let imageURL = post.imageURL {
            image = NSImage(contentsOf: imageURL)
        }
        
        let link = post.link ?? URL(string: "https://wisdombook.life")!
        
        // Check if we need a video for this post (for YouTube or other video platforms)
        // First line of content is used as title for video matching
        let title = content.prefix(60).replacingOccurrences(of: "\n", with: " ")
        // Get or create video for this post
        let entry = WisdomEntry(
            id: UUID(),
            title: String(title),
            content: content,
            reference: nil,
            link: link,
            pubDate: Date(),
            category: .thought
        )
        let videoURL = try? await getOrCreateVideo(for: entry)
        
        // Log video status
        if let url = videoURL {
            logger.info("🎬 Video ready for posting: \(url.lastPathComponent)")
        } else {
            logger.warning("⚠️ No video available for post")
        }
        
        let result = await router.postToAll(
            content: content,
            image: image,
            imageURL: post.imageURL,
            link: link,
            platforms: platforms,
            post: post
        )
        
        // Ping Google if any platform succeeded
        if result.successes > 0 {
            await pingGoogle(url: link)
        }
    }
    
    // MARK: - Google Search Console
    
    /// Ping Google's Indexing API to notify about a published URL
    private func pingGoogle(url: URL) async {
        guard googleIndexing.isConfigured else {
            logger.info("Google Search Console not configured, skipping ping")
            return
        }
        
        do {
            try await googleIndexing.notifyURLUpdated(url)
            logger.info("✅ Google Search Console pinged: \(url.absoluteString)")
        } catch {
            logger.error("⚠️ Google ping failed (non-blocking): \(error.localizedDescription)")
        }
    }
}
