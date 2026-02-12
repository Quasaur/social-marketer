//
//  SocialMarketerApp.swift
//  SocialMarketer
//
//  Native macOS application for Wisdom Book content distribution
//

import SwiftUI

@main
struct SocialMarketerApp: App {
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
    }
    
    private func seedPlatformsIfNeeded() {
        let context = persistenceController.viewContext
        let request = Platform.fetchRequest()
        
        // Canonical V1 platform list
        let canonicalPlatforms: [(String, String)] = [
            ("X (Twitter)", "oauth2"),
            ("Instagram", "graph_api"),
            ("LinkedIn", "oauth2"),
            ("Facebook", "facebook"),
            ("Pinterest", "pinterest")
        ]
        let canonicalNames = Set(canonicalPlatforms.map { $0.0 })
        
        do {
            let existing = try context.fetch(request)
            let existingNames = Set(existing.compactMap { $0.name })
            
            if existing.isEmpty {
                // Fresh seed
                for (name, apiType) in canonicalPlatforms {
                    _ = Platform(context: context, name: name, apiType: apiType)
                }
                try context.save()
                Log.app.notice("Seeded \(canonicalPlatforms.count) default platforms")
            } else {
                var changed = false
                
                // Add missing platforms
                for (name, apiType) in canonicalPlatforms where !existingNames.contains(name) {
                    _ = Platform(context: context, name: name, apiType: apiType)
                    Log.app.notice("Added missing platform: \(name)")
                    print("[seedPlatforms] Added: \(name)")
                    changed = true
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
        entry.content = """
            Since the creation of Twitter in 2006 I have been posting the Wisdom that The Spirit of Christ has graciously given to me.

            In 2015 I published The Book of Tweets: Proverbs for the Modern Age on Amazon Kindle. In it I placed well over 600 proverbs, maxims and an adages.

            Since that time I have posted another 300 adages on 19 social media platforms in an effort to communicate with the world the critical importance of Biblical Wisdom to our mental health, fortune and survival.

            Now, in the latter days of my earthly journey, I am consolidating all of my work in a single Neo4j AURADB graph database which can be enjoyed by everyone free-of-charge through my new website The Book of Wisdom:

            https://www.wisdombook.life
            """
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
                    print("[syncPlatform] Auto-enabled: \(name)")
                } else if !hasCredentials && platform.isEnabled {
                    platform.isEnabled = false
                    updated += 1
                    Log.app.notice("Auto-disabled platform: \(name) (no Keychain credentials)")
                    print("[syncPlatform] Auto-disabled: \(name)")
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
        default:
            // Fallback: try the display name directly
            return ks.exists(for: platformName)
        }
    }
}

