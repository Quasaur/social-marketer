//
//  SocialMarketerApp.swift
//  SocialMarketer
//
//  Native macOS application for Wisdom Book content distribution
//

import SwiftUI

/// AppDelegate for handling application lifecycle events
/// Specifically for graceful shutdown of Social Effects service
class SocialMarketerAppDelegate: NSObject, NSApplicationDelegate {
    
    private var isShuttingDown = false
    
    /// Called when user tries to quit the app - allows us to delay termination for cleanup
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isShuttingDown else {
            Log.app.notice("⚠️ applicationShouldTerminate called but already shutting down")
            return .terminateNow  // Already shutting down, allow it
        }
        
        Log.app.notice("🛑 Social Marketer quitting - initiating graceful shutdown...")
        isShuttingDown = true
        
        // Start shutdown in background but delay termination
        Task {
            Log.app.notice("📱 Shutdown Task started")
            await self.performShutdown()
            Log.app.notice("📱 Shutdown Task completed, replying to terminate")
            // After shutdown completes (or times out), terminate the app
            await MainActor.run {
                NSApp.reply(toApplicationShouldTerminate: true)
            }
        }
        
        Log.app.notice("⏳ Delaying termination for cleanup...")
        // Return .terminateLater to delay termination until we call reply()
        return .terminateLater
    }
    
    /// Called just before termination - last chance for cleanup
    func applicationWillTerminate(_ notification: Notification) {
        Log.app.notice("🛑 applicationWillTerminate called (isShuttingDown: \(self.isShuttingDown))")
        // Shutdown should already be done in applicationShouldTerminate
        // This is a fallback in case that wasn't called
        if !isShuttingDown {
            Log.app.notice("🛑 Fallback shutdown initiated...")
            runSynchronousShutdown()
        } else {
            Log.app.notice("✅ Shutdown already completed in applicationShouldTerminate")
        }
    }
    
    /// Perform async shutdown of Social Effects
    private func performShutdown() async {
        Log.app.notice("🔌 Calling SocialEffectsService.shutdown()...")
        await SocialEffectsService.shared.shutdown()
        Log.app.notice("🔌 SocialEffectsService.shutdown() returned")
    }
    
    /// Synchronous shutdown for fallback scenarios
    private func runSynchronousShutdown() {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await SocialEffectsService.shared.shutdown()
            semaphore.signal()
        }
        
        // Wait up to 3 seconds for shutdown
        _ = semaphore.wait(timeout: .now() + 3)
    }
}

@main
struct SocialMarketerApp: App {
    @NSApplicationDelegateAdaptor(SocialMarketerAppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appTermination) {
                Button("Quit Social Marketer") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
    }
    
    init() {
        Log.app.notice("Social Marketer launched")
        
        // Handle command-line arguments for launchd scheduled runs
        if CommandLine.arguments.contains("--scheduled-post") {
            Log.app.notice("Running in scheduled-post mode via launchd")
            Task {
                let scheduler = PostScheduler()
                await scheduler.executeScheduledPost()
                // Exit after posting (launchd will restart next scheduled time)
                Log.app.notice("Scheduled post complete, exiting")
                exit(0)
            }
        }
        
        // Seed initial platforms if empty
        seedPlatformsIfNeeded()
        
        // Seed introductory post if not already present
        seedIntroductoryPostIfNeeded()
        
        // Sync isEnabled state from Keychain (fixes sandbox → App Group migration)
        syncPlatformEnabledState()
        
        // Auto-update launch agent if installed (self-heals after DerivedData wipes or schedule changes)
        if !CommandLine.arguments.contains("--scheduled-post") {
            let scheduler = PostScheduler()
            scheduler.ensureLaunchAgentCurrent()
        }
        
        // Start Social Effects video generation service (non-blocking)
        // This ensures video generation is ready when needed
        startSocialEffectsService()
    }
    
    /// Start Social Effects service in background
    /// Video generation requires this local service to be running continuously
    /// Server lifecycle: started on app launch → runs persistently → stopped on app quit
    private func startSocialEffectsService() {
        Task {
            Log.app.notice("🚀 Ensuring Social Effects service is running...")
            
            // Use the service's ensure method which is idempotent
            let running = await SocialEffectsService.shared.ensureServerRunning()
            
            if running {
                Log.app.notice("✅ Social Effects service ready (port 5390)")
                ErrorLog.shared.log(
                    category: "App",
                    message: "Social Effects service active",
                    detail: "Video generation ready on port 5390"
                )
            } else {
                Log.app.error("❌ Failed to start Social Effects service")
                ErrorLog.shared.log(
                    category: "App",
                    message: "Social Effects failed to start",
                    detail: "Video generation will not be available. Check that the binary exists at /Users/quasaur/Developer/social-effects/.build/debug/SocialEffects"
                )
            }
        }
    }
    
    private func seedPlatformsIfNeeded() {
        let context = persistenceController.viewContext
        let request = Platform.fetchRequest()
        
        // Canonical V1 platform list (includes TikTok for future use)
        let canonicalPlatforms: [(String, String)] = [
            ("X (Twitter)", "oauth2"),
            ("Instagram", "graph_api"),
            ("LinkedIn", "oauth2"),
            ("Facebook", "facebook"),
            ("Pinterest", "pinterest"),
            ("TikTok", "tiktok")  // Pipeline coming soon
        ]
        let canonicalNames = Set(canonicalPlatforms.map { $0.0 })
        
        do {
            let existing = try context.fetch(request)
            let existingNames = Set(existing.compactMap { $0.name })
            
            if existing.isEmpty {
                // Fresh seed
                for (name, apiType) in canonicalPlatforms {
                    let platform = Platform(context: context, name: name, apiType: apiType)
                    // Set default media type preference for video-capable platforms
                    if name == "Instagram" || name == "TikTok" {
                        platform.preferredMediaType = "video"
                    }
                }
                try context.save()
                Log.app.notice("Seeded \(canonicalPlatforms.count) default platforms")
            } else {
                var changed = false
                
                // Add missing platforms
                for (name, apiType) in canonicalPlatforms where !existingNames.contains(name) {
                    let platform = Platform(context: context, name: name, apiType: apiType)
                    // Set default media type preference for video-capable platforms
                    if name == "Instagram" || name == "TikTok" {
                        platform.preferredMediaType = "video"
                    }
                    Log.app.notice("Added missing platform: \(name)")
                    if Log.isDebugMode {
                        Log.debug("[seedPlatforms] Added: \(name)", category: "App")
                    }
                    changed = true
                }
                
                // Set default media type for existing platforms that don't have it set
                for platform in existing {
                    let name = platform.name ?? ""
                    if (name == "Instagram" || name == "TikTok") && platform.preferredMediaType == nil {
                        platform.preferredMediaType = "video"
                        Log.app.notice("Set default media preference for \(name): video")
                        changed = true
                    }
                }
                
                // Remove obsolete platforms (not in canonical list and no credentials)
                for platform in existing {
                    let name = platform.name ?? ""
                    if !canonicalNames.contains(name) {
                        context.delete(platform)
                        Log.app.notice("Removed obsolete platform: \(name)")
                        print("[seedPlatforms] Removed: \(name)")
                        changed = true
                    }
                }
                
                if changed {
                    try context.save()
                } else {
                    Log.app.debug("Platform seed skipped — all \(existing.count) platforms current")
                }
            }
        } catch {
            Log.app.error("Failed to seed platforms: \(error.localizedDescription)")
            ErrorLog.shared.log(category: "App", message: "Failed to seed platforms", detail: error.localizedDescription)
        }
    }
    
    private func seedIntroductoryPostIfNeeded() {
        let context = persistenceController.viewContext
        let introLink = "socialmarketer://introduction"
        
        // Skip if already seeded
        if CachedWisdomEntry.findByLink(introLink, in: context) != nil {
            Log.app.debug("Introductory post already exists — skipping seed")
            return
        }
        
        let entry = CachedWisdomEntry(context: context)
        entry.id = UUID()
        entry.title = "Welcome to The Book of Wisdom"
        entry.content = ContentConstants.introText
        entry.category = WisdomEntry.WisdomCategory.introduction.rawValue
        entry.linkString = introLink
        entry.pubDate = Date()
        entry.fetchedAt = Date()
        entry.usedCount = 0
        
        do {
            try context.save()
            Log.app.notice("Seeded introductory post")
        } catch {
            Log.app.error("Failed to seed introductory post: \(error.localizedDescription)")
            ErrorLog.shared.log(category: "App", message: "Failed to seed introductory post", detail: error.localizedDescription)
        }
    }
    
    /// Sync platform isEnabled state with Keychain credentials.
    /// Heals the sandbox → App Group store migration: if credentials exist, enable the platform.
    private func syncPlatformEnabledState() {
        let context = persistenceController.viewContext
        let request = Platform.fetchRequest()
        
        do {
            let platforms = try context.fetch(request)
            var updated = 0
            
            for platform in platforms {
                let name = platform.name ?? ""
                let hasCredentials = keychainHasCredentials(for: name)
                
                if hasCredentials && !platform.isEnabled {
                    platform.isEnabled = true
                    updated += 1
                    Log.app.notice("Auto-enabled platform: \(name) (Keychain credentials found)")
                    if Log.isDebugMode {
                        Log.debug("[syncPlatform] Auto-enabled: \(name)", category: "App")
                    }
                } else if !hasCredentials && platform.isEnabled {
                    platform.isEnabled = false
                    updated += 1
                    Log.app.notice("Auto-disabled platform: \(name) (no Keychain credentials)")
                    if Log.isDebugMode {
                        Log.debug("[syncPlatform] Auto-disabled: \(name)", category: "App")
                    }
                }
            }
            
            if updated > 0 {
                try context.save()
                Log.app.notice("Synced \(updated) platform enabled states from Keychain")
            }
        } catch {
            Log.app.error("Failed to sync platform states: \(error.localizedDescription)")
        }
    }
    
    /// Check if Keychain has credentials for a platform using the actual keys
    /// the connectors store under (not the display name)
    private func keychainHasCredentials(for platformName: String) -> Bool {
        let ks = KeychainService.shared
        
        switch platformName {
        case "X (Twitter)":
            return ks.exists(for: "twitter_oauth1")
        case "LinkedIn":
            return ks.exists(for: "api_creds_linkedin") || ks.exists(for: "oauth_linkedin")
        case "Facebook":
            return ks.exists(for: "api_creds_facebook") || ks.exists(for: "oauth_facebook")
        case "Instagram":
            return ks.exists(for: "api_creds_instagram") || ks.exists(for: "oauth_instagram")
        case "Pinterest":
            return ks.exists(for: "api_creds_pinterest") || ks.exists(for: "oauth_pinterest")
        case "TikTok":
            return ks.exists(for: "api_creds_tiktok") || ks.exists(for: "oauth_tiktok")
        default:
            // Fallback: try the display name directly
            return ks.exists(for: platformName)
        }
    }
}

