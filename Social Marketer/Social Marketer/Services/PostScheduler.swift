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
    
    /// Directory where Social Effects saves generated videos (from Configuration)
    private var videoStorageDir: String { AppConfiguration.Paths.videoStorage }
    
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
    
    /// Execute scheduled posting (called by launchd or manually).
    /// Now queue-driven: processes pending posts from Core Data queue.
    func executeScheduledPost() async {
        logger.info("Executing scheduled post (queue-driven)...")
        
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
        
        // Process the queue (auto-populates from RSS if empty)
        await processQueue()
        
        logger.info("Scheduled posting complete")
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
        let link = URL(string: AppConfiguration.URLs.wisdomBook)!
        
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
    
    /// Process all pending posts whose scheduled date has arrived.
    /// If queue is empty, auto-populates from RSS feed to ensure continuous posting.
    func processQueue() async {
        let context = PersistenceController.shared.viewContext
        
        // Auto-populate queue if empty (fetch from RSS)
        let pendingPosts = Post.fetchPending(in: context)
        if pendingPosts.isEmpty {
            logger.info("Queue is empty - auto-populating from RSS feed...")
            await autoPopulateQueueFromRSS()
        }
        
        // Re-fetch after potential population
        let postsToProcess = Post.fetchPending(in: context)
        
        let now = Date()
        let duePosts = postsToProcess.filter { post in
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
    
    /// Auto-populates the Post Queue from RSS feed when empty.
    /// Schedules one post per day for subsequent days.
    /// This is public so test post buttons can populate the queue without posting to all platforms.
    func autoPopulateQueueFromRSS() async {
        let context = PersistenceController.shared.viewContext
        
        print("[AUTO-POPULATE] Starting RSS feed fetch...")
        
        do {
            let rssParser = RSSParser()
            
            // Fetch from all feed types for maximum variety
            var allEntries: [WisdomEntry] = []
            
            // Try quotes feed (has wisdom:source with book names)
            print("[AUTO-POPULATE] Fetching quotes feed...")
            if let quotesURL = URL(string: AppConfiguration.URLs.wisdomBook + "/feed/quotes.xml"),
               let quotes = try? await rssParser.fetchFeed(url: quotesURL) {
                print("[AUTO-POPULATE] Quotes feed: \(quotes.count) entries")
                allEntries.append(contentsOf: quotes)
            } else {
                print("[AUTO-POPULATE] Quotes feed: failed or empty")
            }
            
            // Try passages feed (has wisdom:source with Bible references)
            print("[AUTO-POPULATE] Fetching passages feed...")
            if let passagesURL = URL(string: AppConfiguration.URLs.wisdomBook + "/feed/passages.xml"),
               let passages = try? await rssParser.fetchFeed(url: passagesURL) {
                print("[AUTO-POPULATE] Passages feed: \(passages.count) entries")
                allEntries.append(contentsOf: passages)
            } else {
                print("[AUTO-POPULATE] Passages feed: failed or empty")
            }
            
            // Try thoughts feed (lacks wisdom:source - skip expensive extractBookName)
            // NOTE: Thoughts are original content without book references, so we don't
            // try to extract book names (which would fail anyway)
            print("[AUTO-POPULATE] Fetching thoughts feed...")
            if let thoughtsURL = URL(string: AppConfiguration.URLs.wisdomBook + "/feed/thoughts.xml"),
               let thoughts = try? await rssParser.fetchFeed(url: thoughtsURL) {
                print("[AUTO-POPULATE] Thoughts feed: \(thoughts.count) entries")
                allEntries.append(contentsOf: thoughts)
            } else {
                print("[AUTO-POPULATE] Thoughts feed: failed or empty")
            }
            
            // Fall back to daily feed if others are empty
            if allEntries.isEmpty {
                print("[AUTO-POPULATE] All feeds empty, trying daily feed...")
                if let daily = try? await rssParser.fetchDaily() {
                    print("[AUTO-POPULATE] Daily feed: 1 entry")
                    allEntries.append(daily)
                }
            }
            
            guard !allEntries.isEmpty else {
                logger.warning("No entries available from any RSS feeds")
                return
            }
            
            // Shuffle for variety, then schedule one per day
            let shuffledEntries = allEntries.shuffled()
            let entriesToAdd = shuffledEntries.prefix(5) // Up to 5 days worth
            
            let calendar = Calendar.current
            let now = Date()
            
            for (index, entry) in entriesToAdd.enumerated() {
                // Schedule for subsequent days (tomorrow, day after, etc.)
                // First entry scheduled for today/now (if queue was empty)
                // Subsequent entries scheduled for future days
                let daysToAdd = index
                let scheduledDate = calendar.date(byAdding: .day, value: daysToAdd, to: now) ?? now
                createPostFromEntry(entry, scheduledFor: scheduledDate, in: context)
            }
            
            PersistenceController.shared.save()
            logger.info("Added \(entriesToAdd.count) entries to queue (scheduled for next \(entriesToAdd.count) days)")
            print("[AUTO-POPULATE] Complete: Added \(entriesToAdd.count) entries to queue")
            
        } catch {
            logger.error("Failed to auto-populate queue: \(error.localizedDescription)")
            print("[AUTO-POPULATE] Failed: \(error.localizedDescription)")
        }
    }
    
    /// Creates a Post entity from a WisdomEntry with specific schedule date
    private func createPostFromEntry(_ entry: WisdomEntry, scheduledFor date: Date, in context: NSManagedObjectContext) {
        let post = Post(
            context: context,
            content: entry.content,
            imageURL: nil, // Will be generated at post time
            link: entry.link
        )
        post.scheduledDate = date
        logger.debug("Created post from entry: \(entry.title ?? "Untitled") scheduled for \(date)")
    }
    
    /// Post a single queued post to all enabled platforms — delegates to PlatformRouter
    /// Generates graphic at post time if not already available, checks for existing video
    private func postFromQueue(_ post: Post, to platforms: [Platform]) async {
        guard let content = post.content else {
            logger.warning("Skipping post with no content")
            post.postStatus = .failed
            PersistenceController.shared.save()
            return
        }
        
        let link = post.link ?? URL(string: AppConfiguration.URLs.wisdomBook)!
        
        // Build entry for graphic/video generation
        let title = content.prefix(60).replacingOccurrences(of: "\n", with: " ")
        let entry = WisdomEntry(
            id: UUID(),
            title: String(title),
            content: content,
            reference: nil,
            link: link,
            pubDate: Date(),
            category: .thought
        )
        
        // Generate quote graphic (if not already generated)
        var image: NSImage?
        var tempImageURL: URL?
        
        if let existingImageURL = post.imageURL,
           let existingImage = NSImage(contentsOf: existingImageURL) {
            // Use pre-generated image
            image = existingImage
            tempImageURL = existingImageURL
            logger.debug("Using pre-generated image for post")
        } else {
            // Generate graphic now
            logger.info("Generating quote graphic for post...")
            let generator = QuoteGraphicGenerator()
            if let generatedImage = generator.generate(from: entry) {
                image = generatedImage
                
                // Save to temp for platforms that need URL
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("wisdom_\(Date().timeIntervalSince1970).png")
                do {
                    try generator.save(generatedImage, to: tempURL)
                    tempImageURL = tempURL
                    logger.info("Quote graphic generated and saved")
                } catch {
                    logger.error("Failed to save generated image: \(error.localizedDescription)")
                }
            } else {
                logger.error("Failed to generate quote graphic")
            }
        }
        
        // Get or create video for this post
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
            imageURL: tempImageURL,
            link: link,
            platforms: platforms,
            post: post
        )
        
        // Cleanup temp file if we generated one
        if let tempURL = tempImageURL, tempURL != post.imageURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
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
