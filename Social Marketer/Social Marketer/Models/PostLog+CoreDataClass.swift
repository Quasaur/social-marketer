//
//  PostLog+CoreDataClass.swift
//  SocialMarketer
//
//  Core Data entity for post result logging
//

import Foundation
import CoreData

@objc(PostLog)
public class PostLog: NSManagedObject {
    
    /// Convenience initializer for success
    convenience init(context: NSManagedObjectContext, post: Post, platform: Platform, postID: String?, postURL: URL?) {
        self.init(context: context)
        self.id = UUID()
        self.post = post
        self.platform = platform
        self.success = true
        self.externalPostID = postID
        self.externalPostURLString = postURL?.absoluteString
        self.timestamp = Date()
    }
    
    /// Convenience initializer for failure
    convenience init(context: NSManagedObjectContext, post: Post, platform: Platform, error: String) {
        self.init(context: context)
        self.id = UUID()
        self.post = post
        self.platform = platform
        self.success = false
        self.errorMessage = error
        self.timestamp = Date()
    }
    
    /// Computed property for external post URL
    var externalPostURL: URL? {
        get { externalPostURLString.flatMap { URL(string: $0) } }
        set { externalPostURLString = newValue?.absoluteString }
    }
}

// MARK: - Fetchable

extension PostLog {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PostLog> {
        return NSFetchRequest<PostLog>(entityName: "PostLog")
    }
    
    /// Fetch recent logs
    static func fetchRecent(limit: Int = 50, in context: NSManagedObjectContext) -> [PostLog] {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PostLog.timestamp, ascending: false)]
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    /// Fetch logs for a specific platform
    static func fetch(for platform: Platform, in context: NSManagedObjectContext) -> [PostLog] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "platform == %@", platform)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PostLog.timestamp, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
}

// MARK: - Properties

extension PostLog {
    
    @NSManaged public var id: UUID?
    @NSManaged public var success: Bool
    @NSManaged public var externalPostID: String?
    @NSManaged public var externalPostURLString: String?
    @NSManaged public var errorMessage: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var post: Post?
    @NSManaged public var platform: Platform?
}

// MARK: - Identifiable

extension PostLog: Identifiable {}
