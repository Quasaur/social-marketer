//
//  PersistenceController.swift
//  SocialMarketer
//
//  Core Data stack with App Group support for launchd helper
//

import CoreData
import os.log

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
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "Persistence")
    
    /// App Group identifier for shared container
    private static let appGroupIdentifier = "group.com.wisdombook.SocialMarketer"
    
    // MARK: - Initialization
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SocialMarketer")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Use App Group shared container for launchd helper access
            if let storeURL = Self.sharedStoreURL {
                container.persistentStoreDescriptions.first?.url = storeURL
                logger.info("Core Data store: \(storeURL.path)")
            }
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                self.logger.error("Core Data load failed: \(error.localizedDescription)")
                fatalError("Core Data load failed: \(error)")
            }
            self.logger.info("Core Data loaded successfully")
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - App Group Support
    
    /// Shared store URL - uses App Group if available, falls back to Application Support
    private static var sharedStoreURL: URL? {
        // Try App Group first (for launchd helper access)
        if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return appGroupURL.appendingPathComponent("SocialMarketer.sqlite")
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
