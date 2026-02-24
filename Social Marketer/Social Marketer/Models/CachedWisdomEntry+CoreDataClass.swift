//
//  CachedWisdomEntry+CoreDataClass.swift
//  SocialMarketer
//
//  Core Data entity for posted content history (formerly Content Library)
//

import Foundation
import CoreData

/// Posted Content History entry
/// Tracks content that has been posted to platforms with image/video counts
@objc(CachedWisdomEntry)
public class CachedWisdomEntry: NSManagedObject {
    
    /// Convenience initializer from WisdomEntry (when creating from queue post)
    convenience init(context: NSManagedObjectContext, from entry: WisdomEntry) {
        self.init(context: context)
        self.id = entry.id
        self.title = entry.title
        self.content = entry.content
        self.reference = entry.reference
        self.linkString = entry.link.absoluteString
        self.category = entry.category.rawValue
        self.pubDate = entry.pubDate
        self.fetchedAt = Date()
        self.usedCount = 0
        self.postedImageCount = 0
        self.postedVideoCount = 0
    }
    
    /// Convenience initializer for manual/posted content
    convenience init(context: NSManagedObjectContext, title: String?, content: String?, link: URL, category: WisdomEntry.WisdomCategory = .thought) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.content = content
        self.linkString = link.absoluteString
        self.category = category.rawValue
        self.fetchedAt = Date()
        self.usedCount = 0
        self.postedImageCount = 0
        self.postedVideoCount = 0
    }
    
    /// Computed property for link URL
    var link: URL? {
        get { linkString.flatMap { URL(string: $0) } }
        set { linkString = newValue?.absoluteString }
    }
    
    /// Computed property for category enum
    var wisdomCategory: WisdomEntry.WisdomCategory {
        get { WisdomEntry.WisdomCategory(rawValue: category ?? "Thought") ?? .thought }
        set { category = newValue.rawValue }
    }
    
    /// Mark this entry as used for posting
    func markAsUsed() {
        usedCount += 1
        lastUsedAt = Date()
    }
    
    /// Mark this entry as posted as an image
    func markPostedAsImage() {
        postedImageCount += 1
        markAsUsed()
    }
    
    /// Mark this entry as posted as a video
    func markPostedAsVideo() {
        postedVideoCount += 1
        markAsUsed()
    }
}

// MARK: - Fetchable

extension CachedWisdomEntry {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedWisdomEntry> {
        return NSFetchRequest<CachedWisdomEntry>(entityName: "CachedWisdomEntry")
    }
    
    /// Fetch all posted content sorted by last posted date (most recent first)
    static func fetchAllPosted(in context: NSManagedObjectContext) -> [CachedWisdomEntry] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "usedCount > 0")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedWisdomEntry.lastUsedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    /// Fetch posted entries by category
    static func fetchPosted(category: WisdomEntry.WisdomCategory, in context: NSManagedObjectContext) -> [CachedWisdomEntry] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "category == %@ AND usedCount > 0", category.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedWisdomEntry.lastUsedAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    /// Find existing entry by link URL (for deduplication)
    static func findByLink(_ linkString: String, in context: NSManagedObjectContext) -> CachedWisdomEntry? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "linkString == %@", linkString)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            return nil
        }
    }
    
    /// Fetch least-used entries for intelligent selection (excludes Introduction posts)
    /// Note: This may include entries not yet in history (usedCount = 0)
    static func fetchLeastUsed(limit: Int = 10, in context: NSManagedObjectContext) -> [CachedWisdomEntry] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "category != %@", WisdomEntry.WisdomCategory.introduction.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CachedWisdomEntry.usedCount, ascending: true),
            NSSortDescriptor(keyPath: \CachedWisdomEntry.fetchedAt, ascending: false)
        ]
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
}

// MARK: - Properties

extension CachedWisdomEntry {
    
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var reference: String?
    @NSManaged public var linkString: String?
    @NSManaged public var category: String?
    @NSManaged public var pubDate: Date?      // Original publication date (if from RSS)
    @NSManaged public var fetchedAt: Date?    // When this entry was first added
    @NSManaged public var usedCount: Int16    // Total number of times posted
    @NSManaged public var lastUsedAt: Date?   // Most recent post date
    @NSManaged public var postedImageCount: Int16  // Number of image posts
    @NSManaged public var postedVideoCount: Int16  // Number of video posts
}

// MARK: - Identifiable

extension CachedWisdomEntry: Identifiable {}
