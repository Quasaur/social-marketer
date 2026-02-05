//
//  Platform+CoreDataClass.swift
//  SocialMarketer
//
//  Core Data entity for social media platforms
//

import Foundation
import CoreData

@objc(Platform)
public class Platform: NSManagedObject {
    
    /// Convenience initializer
    convenience init(context: NSManagedObjectContext, name: String, apiType: String) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.apiType = apiType
        self.isEnabled = false
        self.createdAt = Date()
    }
}

// MARK: - Fetchable

extension Platform {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Platform> {
        return NSFetchRequest<Platform>(entityName: "Platform")
    }
    
    /// Fetch all enabled platforms
    static func fetchEnabled(in context: NSManagedObjectContext) -> [Platform] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Platform.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    /// Find platform by name
    static func find(name: String, in context: NSManagedObjectContext) -> Platform? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
}

// MARK: - Properties

extension Platform {
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var apiType: String?
    @NSManaged public var isEnabled: Bool
    @NSManaged public var lastPostDate: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var posts: NSSet?
}

// MARK: - Relationships

extension Platform {
    
    @objc(addPostsObject:)
    @NSManaged public func addToPosts(_ value: Post)
    
    @objc(removePostsObject:)
    @NSManaged public func removeFromPosts(_ value: Post)
    
    @objc(addPosts:)
    @NSManaged public func addToPosts(_ values: NSSet)
    
    @objc(removePosts:)
    @NSManaged public func removeFromPosts(_ values: NSSet)
}

// MARK: - Identifiable

extension Platform: Identifiable {}
