//
//  PersistenceController.swift
//  SocialMarketer
//
//  Core Data stack with App Group support for launchd helper
//

import CoreData

/// Manages the Core Data stack with App Group support
final class PersistenceController {
    
    // MARK: - Singleton
    
    static let shared = PersistenceController()
    
    /// Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Add sample data for previews
        let platform = Platform(context: viewContext)
        platform.id = UUID()
        platform.name = "X (Twitter)"
        platform.apiType = "oauth2"
        platform.isEnabled = true
        
        do {
            try viewContext.save()
        } catch {
            fatalError("Preview Core Data save failed: \(error)")
        }
        
        return controller
    }()
    
    // MARK: - Properties
    
    let container: NSPersistentContainer
    private let logger = Log.persistence
    
    /// App Group identifier for shared container
    private static let appGroupIdentifier = "group.com.wisdombook.SocialMarketer"
    
    // MARK: - Initialization
    
    init(inMemory: Bool = false) {
        // Use Xcode's auto-generated model name (with underscore)
        container = NSPersistentContainer(name: "Social_Marketer")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use App Group shared container for launchd helper access
            if let storeURL = Self.sharedStoreURL {
                container.persistentStoreDescriptions.first?.url = storeURL
                logger.notice("Core Data store: \(storeURL.path)")
                if Log.isDebugMode {
                    Log.debug("[PersistenceController] Store path: \(storeURL.path)", category: "Persistence")
                }
            }
        }
        
        // Enable cross-process change detection (GUI ↔ launchd scheduler)
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                self.logger.error("Core Data load failed: \(error.localizedDescription)")
                Log.persistence.error("⚠️ Core Data Error: \(error.localizedDescription)")
                Task { @MainActor in
                    ErrorLog.shared.log(category: "Persistence", message: "Core Data load failed", detail: error.localizedDescription)
                }
            } else {
                self.logger.notice("Core Data loaded successfully")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Observe remote store changes (from launchd process) and refresh the view context
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { [weak container] _ in
            guard let context = container?.viewContext else { return }
            context.perform {
                context.refreshAllObjects()
            }
        }
    }
    
    // MARK: - App Group Support
    
    /// Shared store URL - uses App Group if available AND accessible, falls back to Application Support
    private static var sharedStoreURL: URL? {
        // Try App Group first (for launchd helper access)
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            // Verify we can actually write to this directory
            let testFile = appGroupURL.appendingPathComponent(".write_test")
            do {
                try "test".write(to: testFile, atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(at: testFile)
                // App Group is accessible
                return appGroupURL.appendingPathComponent("SocialMarketer.sqlite")
            } catch {
                // App Group exists but we can't write to it (sandbox issue)
                Log.persistence.warning("App Group not accessible, using Application Support: \(error.localizedDescription)")
            }
        }
        
        // Fallback to Application Support (for development/testing)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("SocialMarketer")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent("SocialMarketer.sqlite")
    }
    
    // MARK: - Convenience Methods
    
    /// Main view context
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Create a background context for async operations
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
    
    /// Save the view context if there are changes
    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            logger.debug("Context saved successfully")
        } catch {
            logger.error("Save failed: \(error.localizedDescription)")
        }
    }
    
    /// Save a background context
    func save(context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            logger.debug("Background context saved")
        } catch {
            logger.error("Background save failed: \(error.localizedDescription)")
        }
    }
}
