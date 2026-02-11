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
    }
    
    private func seedPlatformsIfNeeded() {
        let context = persistenceController.viewContext
        let request = Platform.fetchRequest()
        
        do {
            let count = try context.count(for: request)
            if count == 0 {
                // Create V1 platforms
                let platforms = [
                    ("X (Twitter)", "oauth2"),
                    ("Instagram", "graph_api"),
                    ("LinkedIn", "oauth2"),
                    ("Facebook", "facebook"),
                    ("Pinterest", "pinterest")
                ]
                
                for (name, apiType) in platforms {
                    _ = Platform(context: context, name: name, apiType: apiType)
                }
                
                try context.save()
                Log.app.notice("Seeded \(platforms.count) default platforms")
            } else {
                Log.app.debug("Platform seed skipped — \(count) platforms already exist")
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
}

