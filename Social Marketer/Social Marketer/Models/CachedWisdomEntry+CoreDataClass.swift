//
//  CachedWisdomEntry+CoreDataClass.swift
//  SocialMarketer
//
//  Core Data entity for cached RSS wisdom entries
//

import Foundation
import CoreData

@objc(CachedWisdomEntry)
public class CachedWisdomEntry: NSManagedObject {
    
    /// Convenience initializer from WisdomEntry
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
}

// MARK: - Fetchable

extension CachedWisdomEntry {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedWisdomEntry> {
        return NSFetchRequest<CachedWisdomEntry>(entityName: "CachedWisdomEntry")
    }
    
    /// Fetch all cached entries sorted by publication date
    static func fetchAll(in context: NSManagedObjectContext) -> [CachedWisdomEntry] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedWisdomEntry.pubDate, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    /// Fetch entries by category
    static func fetch(category: WisdomEntry.WisdomCategory, in context: NSManagedObjectContext) -> [CachedWisdomEntry] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedWisdomEntry.pubDate, ascending: false)]
        
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
    static func fetchLeastUsed(limit: Int = 10, in context: NSManagedObjectContext) -> [CachedWisdomEntry] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "category != %@", WisdomEntry.WisdomCategory.introduction.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \CachedWisdomEntry.usedCount, ascending: true),
            NSSortDescriptor(keyPath: \CachedWisdomEntry.pubDate, ascending: false)
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
    @NSManaged public var pubDate: Date?
    @NSManaged public var fetchedAt: Date?
    @NSManaged public var usedCount: Int16
    @NSManaged public var lastUsedAt: Date?
}

// MARK: - Identifiable

extension CachedWisdomEntry: Identifiable {}
