//
//  Post+CoreDataClass.swift
//  SocialMarketer
//
//  Core Data entity for scheduled/published posts
//

import Foundation
import CoreData

/// Post status enumeration
enum PostStatus: String {
    case pending = "pending"
    case posted = "posted"
    case failed = "failed"
}

@objc(Post)
public class Post: NSManagedObject {
    
    /// Convenience initializer
    convenience init(context: NSManagedObjectContext, content: String, imageURL: URL?, link: URL) {
        self.init(context: context)
        self.id = UUID()
        self.content = content
        self.imageURLString = imageURL?.absoluteString
        self.linkString = link.absoluteString
        self.status = PostStatus.pending.rawValue
        self.scheduledDate = Date()
        self.createdAt = Date()
    }
    
    /// Computed property for status enum
    var postStatus: PostStatus {
        get { PostStatus(rawValue: status ?? "pending") ?? .pending }
        set { status = newValue.rawValue }
    }
    
    /// Computed property for image URL
    var imageURL: URL? {
        get { imageURLString.flatMap { URL(string: $0) } }
        set { imageURLString = newValue?.absoluteString }
    }
    
    /// Computed property for link URL
    var link: URL? {
        get { linkString.flatMap { URL(string: $0) } }
        set { linkString = newValue?.absoluteString }
    }
}

// MARK: - Fetchable

extension Post {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Post> {
        return NSFetchRequest<Post>(entityName: "Post")
    }
    
    /// Fetch pending posts
    static func fetchPending(in context: NSManagedObjectContext) -> [Post] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", PostStatus.pending.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Post.scheduledDate, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    /// Fetch posts for today
    static func fetchToday(in context: NSManagedObjectContext) -> [Post] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "postedDate >= %@ AND postedDate < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Post.postedDate, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
}

// MARK: - Properties

extension Post {
    
    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var imageURLString: String?
    @NSManaged public var linkString: String?
    @NSManaged public var status: String?
    @NSManaged public var scheduledDate: Date?
    @NSManaged public var postedDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var logs: NSSet?
}

// MARK: - Relationships

extension Post {
    
    @objc(addLogsObject:)
    @NSManaged public func addToLogs(_ value: PostLog)
    
    @objc(removeLogsObject:)
    @NSManaged public func removeFromLogs(_ value: PostLog)
    
    @objc(addLogs:)
    @NSManaged public func addToLogs(_ values: NSSet)
    
    @objc(removeLogs:)
    @NSManaged public func removeFromLogs(_ values: NSSet)
}

// MARK: - Identifiable

extension Post: Identifiable {}
