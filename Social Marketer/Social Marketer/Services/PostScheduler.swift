//
//  PostScheduler.swift
//  SocialMarketer
//
//  Background scheduler for automated posting with launchd support
//

import Foundation
import os.log

/// Manages scheduled posting across platforms
actor PostScheduler {
    
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "Scheduler")
    private var isRunning = false
    
    // MARK: - launchd Configuration
    
    private static let launchdLabel = "com.wisdombook.SocialMarketer"
    private static let launchdPlistName = "com.wisdombook.SocialMarketer.plist"
    
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
        static let youtube = DateComponents(hour: 9, minute: 0)
        static let substack = DateComponents(hour: 10, minute: 0)
    }
    
    // MARK: - launchd Management
    
    /// Check if the launch agent is installed
    var isLaunchAgentInstalled: Bool {
        FileManager.default.fileExists(atPath: Self.installedPlistURL.path)
    }
    
    /// Install the launch agent for background scheduling
    func installLaunchAgent() throws {
        let fileManager = FileManager.default
        
        // Create LaunchAgents directory if needed
        if !fileManager.fileExists(atPath: Self.launchAgentsURL.path) {
            try fileManager.createDirectory(at: Self.launchAgentsURL, withIntermediateDirectories: true)
        }
        
        // Get the bundled plist
        guard let bundledPlistURL = Bundle.main.url(forResource: "com.wisdombook.SocialMarketer", withExtension: "plist") else {
            throw SchedulerError.plistNotFound
        }
        
        // Copy to LaunchAgents
        if fileManager.fileExists(atPath: Self.installedPlistURL.path) {
            try fileManager.removeItem(at: Self.installedPlistURL)
        }
        try fileManager.copyItem(at: bundledPlistURL, to: Self.installedPlistURL)
        
        // Load the agent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", Self.installedPlistURL.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw SchedulerError.launchctlFailed("load")
        }
        
        logger.info("Launch agent installed and loaded")
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
            
            // 5. Cleanup
            try? FileManager.default.removeItem(at: tempURL)
            
            logger.info("Scheduled posting complete")
            
        } catch {
            logger.error("Scheduled posting failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func postToAllPlatforms(entry: WisdomEntry, imageURL: URL) async {
        let caption = buildCaption(from: entry)
        
        // Get enabled platforms from Core Data
        let context = PersistenceController.shared.viewContext
        let enabledPlatforms = Platform.fetchEnabled(in: context)
        
        if enabledPlatforms.isEmpty {
            logger.warning("No platforms enabled. Configure platforms in the app.")
            return
        }
        
        for platform in enabledPlatforms {
            logger.info("Posting to \(platform.name ?? "Unknown")...")
            
            // Platform-specific posting will be implemented in Phase 3
            // For now, log the intent
            logger.info("Would post to \(platform.name ?? "Unknown"): \(caption.prefix(50))...")
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
