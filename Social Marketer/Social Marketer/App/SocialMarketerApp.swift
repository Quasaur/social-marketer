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
        // Handle command-line arguments for launchd scheduled runs
        if CommandLine.arguments.contains("--scheduled-post") {
            Task {
                let scheduler = PostScheduler()
                await scheduler.executeScheduledPost()
                // Exit after posting (launchd will restart next scheduled time)
                exit(0)
            }
        }
        
        // Seed initial platforms if empty
        seedPlatformsIfNeeded()
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
                    ("YouTube", "google_api"),
                    ("Substack", "rest_api")
                ]
                
                for (name, apiType) in platforms {
                    _ = Platform(context: context, name: name, apiType: apiType)
                }
                
                try context.save()
            }
        } catch {
            print("Failed to seed platforms: \(error)")
        }
    }
}
