//
//  PostScheduler.swift
//  SocialMarketer
//
//  Background scheduler for automated posting with launchd support
//

import Foundation
import AppKit

/// Manages scheduled posting across platforms
@MainActor
final class PostScheduler {
    
    private let logger = Log.scheduler
    private let googleIndexing = GoogleIndexingConnector()
    private var isRunning = false
    
    // MARK: - launchd Configuration
    
    private static let launchdLabel = "com.wisdombook.SocialMarketer"
    private static let launchdPlistName = "com.wisdombook.SocialMarketer.plist"
    
    /// UserDefaults keys for configurable schedule time
    static let scheduleHourKey = "launchd.scheduleHour"
    static let scheduleMinuteKey = "launchd.scheduleMinute"
    
    /// Current schedule time (defaults to 9:00 AM)
    static var scheduledHour: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: scheduleHourKey)
            // 0 is both the default and midnight — use a sentinel to distinguish
            return UserDefaults.standard.object(forKey: scheduleHourKey) != nil ? stored : 9
        }
        set { UserDefaults.standard.set(newValue, forKey: scheduleHourKey) }
    }
    
    static var scheduledMinute: Int {
        get { UserDefaults.standard.integer(forKey: scheduleMinuteKey) }
        set { UserDefaults.standard.set(newValue, forKey: scheduleMinuteKey) }
    }
    
    private static var launchAgentsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }
    
    private static var installedPlistURL: URL {
        launchAgentsURL.appendingPathComponent(launchdPlistName)
    }
    
    // MARK: - Optimal Posting Times (EST)
    
    struct PostingSchedule {
        static let twitter = DateComponents(hour: 9, minute: 0)
        static let linkedin = DateComponents(hour: 10, minute: 0)
        static let facebook = DateComponents(hour: 13, minute: 0)
        static let instagram = DateComponents(hour: 18, minute: 0)
        static let pinterest = DateComponents(hour: 14, minute: 0)
    }
    
    // MARK: - launchd Management
    
    /// Check if the launch agent is installed
    var isLaunchAgentInstalled: Bool {
        FileManager.default.fileExists(atPath: Self.installedPlistURL.path)
    }
    
    /// Auto-install or update the launch agent if the executable path or schedule has changed.
    /// Called on every app launch to self-heal after DerivedData wipes or schedule changes.
    func ensureLaunchAgentCurrent() {
        guard isLaunchAgentInstalled else { return } // respect user's toggle choice
        
        // Read the installed plist and compare executable path + schedule
        guard let data = try? Data(contentsOf: Self.installedPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = plist["ProgramArguments"] as? [String],
              let schedule = plist["StartCalendarInterval"] as? [String: Int] else {
            // Can't read — reinstall
            try? installLaunchAgent()
            return
        }
        
        let installedPath = args.first ?? ""
        let currentPath = Bundle.main.executableURL?.path ?? ""
        let installedHour = schedule["Hour"] ?? -1
        let installedMinute = schedule["Minute"] ?? -1
        
        if installedPath != currentPath || installedHour != Self.scheduledHour || installedMinute != Self.scheduledMinute {
            logger.info("Launch agent outdated — reinstalling (path or schedule changed)")
            try? installLaunchAgent()
        } else {
            logger.debug("Launch agent is current")
        }
    }
    
    /// Install the launch agent for background scheduling
    func installLaunchAgent() throws {
        let fileManager = FileManager.default
        
        // Create LaunchAgents directory if needed
        if !fileManager.fileExists(atPath: Self.launchAgentsURL.path) {
            try fileManager.createDirectory(at: Self.launchAgentsURL, withIntermediateDirectories: true)
        }
        
        // Get the actual executable path from the running app
        guard let executableURL = Bundle.main.executableURL else {
            throw SchedulerError.plistNotFound
        }
        
        // Build plist dictionary with the actual app path
        let plistDict: [String: Any] = [
            "Label": Self.launchdLabel,
            "ProgramArguments": [executableURL.path, "--scheduled-post"],
            "StartCalendarInterval": ["Hour": Self.scheduledHour, "Minute": Self.scheduledMinute],
            "RunAtLoad": false,
            "KeepAlive": false,
            "StandardOutPath": "/tmp/com.wisdombook.SocialMarketer.out.log",
            "StandardErrorPath": "/tmp/com.wisdombook.SocialMarketer.err.log",
            "EnvironmentVariables": ["PATH": "/usr/local/bin:/usr/bin:/bin"],
            "WorkingDirectory": "/tmp",
            "ProcessType": "Background",
            "Nice": 10
        ]
        
        // Write the plist
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistDict,
            format: .xml,
            options: 0
        )
        
        // Remove existing if present
        if fileManager.fileExists(atPath: Self.installedPlistURL.path) {
            // Unload first
            let unloadProcess = Process()
            unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unloadProcess.arguments = ["unload", Self.installedPlistURL.path]
            try? unloadProcess.run()
            unloadProcess.waitUntilExit()
            
            try fileManager.removeItem(at: Self.installedPlistURL)
        }
        
        try plistData.write(to: Self.installedPlistURL)
        
        // Load the agent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", Self.installedPlistURL.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw SchedulerError.launchctlFailed("load")
        }
        
        logger.info("Launch agent installed and loaded from \(executableURL.path)")
    }
    
    /// Uninstall the launch agent
    func uninstallLaunchAgent() throws {
        // Unload the agent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", Self.installedPlistURL.path]
        try process.run()
        process.waitUntilExit()
        
        // Remove the plist
        if FileManager.default.fileExists(atPath: Self.installedPlistURL.path) {
            try FileManager.default.removeItem(at: Self.installedPlistURL)
        }
        
        logger.info("Launch agent unloaded and removed")
    }
    
    // MARK: - Scheduled Post Execution
    
    /// Execute scheduled posting (called by launchd or manually)
    func executeScheduledPost() async {
        logger.info("Executing scheduled post...")
        
        // Diagnostic: log platform state
        let context = PersistenceController.shared.viewContext
        let allPlatforms = (try? context.fetch(Platform.fetchRequest())) ?? []
        let enabledPlatforms = allPlatforms.filter { $0.isEnabled }
        print("[PostScheduler] Platforms: \(allPlatforms.count) total, \(enabledPlatforms.count) enabled")
        for p in allPlatforms {
            print("[PostScheduler]   - \(p.name ?? "?") enabled=\(p.isEnabled) apiType=\(p.apiType ?? "?")")
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
            
            // 4. Post to all enabled platforms
            await postToAllPlatforms(entry: entry, imageURL: tempURL)
            
            // 5. Ping Google Search Console
            await pingGoogle(url: entry.link)
            
            // 6. Cleanup
            try? FileManager.default.removeItem(at: tempURL)
            
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
            
            guard let connector = connectorFor(platform) else { continue }
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
    
    // MARK: - Private Methods
    
    /// Map a Core Data Platform to its API connector
    private func connectorFor(_ platform: Platform) -> PlatformConnector? {
        guard let name = platform.name else { return nil }
        
        switch name {
        case "X (Twitter)":
            return TwitterConnector()
        case "Instagram":
            return InstagramConnector()
        case "LinkedIn":
            return LinkedInConnector()
        case "Facebook":
            return FacebookConnector()
        case "Pinterest":
            return PinterestConnector()
        default:
            logger.warning("Unknown platform: \(name)")
            return nil
        }
    }
    
    /// Map a Core Data Platform to its OAuth platform ID (used for token lookup)
    private func oauthPlatformID(for platform: Platform) -> String? {
        switch platform.name {
        case "X (Twitter)": return "twitter"
        case "Instagram":   return "instagram"
        case "LinkedIn":    return "linkedin"
        case "Facebook":    return "facebook"
        case "Pinterest":   return "pinterest"
        default:            return nil
        }
    }
    
    private func postToAllPlatforms(entry: WisdomEntry, imageURL: URL) async {
        let caption = buildCaption(from: entry)
        
        // Load image from saved URL
        guard let image = NSImage(contentsOf: imageURL) else {
            logger.error("Failed to load image from \(imageURL.path)")
            return
        }
        
        // Get enabled platforms from Core Data
        let context = PersistenceController.shared.viewContext
        let enabledPlatforms = Platform.fetchEnabled(in: context)
        
        if enabledPlatforms.isEmpty {
            logger.warning("No platforms enabled. Configure platforms in the app.")
            return
        }
        
        // Create a Post record
        let post = Post(context: context, content: entry.content, imageURL: imageURL, link: entry.link)
        post.scheduledDate = Date()
        
        var anySuccess = false
        
        for platform in enabledPlatforms {
            let platformName = platform.name ?? "Unknown"
            logger.info("Posting to \(platformName)...")
            
            guard let connector = connectorFor(platform) else {
                let log = PostLog(context: context, post: post, platform: platform, error: "No connector for \(platformName)")
                post.addToLogs(log)
                continue
            }
            
            // Check connector is configured (loads credentials from Keychain)
            guard await connector.isConfigured else {
                let log = PostLog(context: context, post: post, platform: platform, error: "Not configured — connect in Platforms settings")
                post.addToLogs(log)
                logger.warning("\(platformName) not configured, skipping")
                continue
            }
            
            do {
                let result = try await connector.post(image: image, caption: caption, link: entry.link)
                
                if result.success {
                    let log = PostLog(context: context, post: post, platform: platform, postID: result.postID, postURL: result.postURL)
                    post.addToLogs(log)
                    platform.lastPostDate = Date()
                    anySuccess = true
                    logger.info("✅ Posted to \(platformName): \(result.postID ?? "no ID")")
                } else {
                    let errorMsg = result.error?.localizedDescription ?? "Unknown error"
                    let log = PostLog(context: context, post: post, platform: platform, error: errorMsg)
                    post.addToLogs(log)
                    logger.error("❌ Failed to post to \(platformName): \(errorMsg)")
                }
            } catch {
                let log = PostLog(context: context, post: post, platform: platform, error: error.localizedDescription)
                post.addToLogs(log)
                logger.error("❌ Error posting to \(platformName): \(error.localizedDescription)")
            }
        }
        
        // Update post status
        post.postStatus = anySuccess ? .posted : .failed
        post.postedDate = anySuccess ? Date() : nil
        
        PersistenceController.shared.save()
        logger.info("Post results saved — \(anySuccess ? "at least one platform succeeded" : "all platforms failed")")
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
            await postFromQueue(post, to: enabledPlatforms, in: context)
        }
    }
    
    /// Post a single queued post to all enabled platforms
    private func postFromQueue(_ post: Post, to platforms: [Platform], in context: NSManagedObjectContext) async {
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
        var anySuccess = false
        
        for platform in platforms {
            let platformName = platform.name ?? "Unknown"
            
            guard let connector = connectorFor(platform) else {
                let log = PostLog(context: context, post: post, platform: platform, error: "No connector for \(platformName)")
                post.addToLogs(log)
                continue
            }
            
            guard await connector.isConfigured else {
                let log = PostLog(context: context, post: post, platform: platform, error: "Not configured")
                post.addToLogs(log)
                continue
            }
            
            do {
                // If we have an image, post with image. Otherwise post text-only.
                if let img = image {
                    let result = try await connector.post(image: img, caption: content, link: link)
                    
                    if result.success {
                        let log = PostLog(context: context, post: post, platform: platform, postID: result.postID, postURL: result.postURL)
                        post.addToLogs(log)
                        platform.lastPostDate = Date()
                        anySuccess = true
                        logger.info("✅ Queue: Posted to \(platformName)")
                    } else {
                        let errorMsg = result.error?.localizedDescription ?? "Unknown error"
                        let log = PostLog(context: context, post: post, platform: platform, error: errorMsg)
                        post.addToLogs(log)
                    }
                } else {
                    // No image — log as skipped for now
                    let log = PostLog(context: context, post: post, platform: platform, error: "No image available for post")
                    post.addToLogs(log)
                    logger.warning("Skipped \(platformName) — no image")
                }
            } catch {
                let log = PostLog(context: context, post: post, platform: platform, error: error.localizedDescription)
                post.addToLogs(log)
                logger.error("❌ Queue: Error posting to \(platformName): \(error.localizedDescription)")
            }
        }
        
        post.postStatus = anySuccess ? .posted : .failed
        post.postedDate = anySuccess ? Date() : nil
        PersistenceController.shared.save()
        
        // Ping Google if any platform succeeded
        if anySuccess, let link = post.link {
            await pingGoogle(url: link)
        }
    }
    
    private func buildCaption(from entry: WisdomEntry) -> String {
        var caption = entry.content
        
        if let reference = entry.reference {
            caption += "\n\n— \(reference)"
        }
        
        caption += "\n\n🔗 \(entry.link.absoluteString)"
        caption += "\n\n#wisdom #wisdombook #dailywisdom"
        
        return caption
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

// MARK: - Errors

enum SchedulerError: Error, LocalizedError {
    case plistNotFound
    case launchctlFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .plistNotFound:
            return "Launch agent plist not found in app bundle"
        case .launchctlFailed(let command):
            return "launchctl \(command) failed"
        }
    }
}
