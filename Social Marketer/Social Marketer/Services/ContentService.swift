//
//  ContentService.swift
//  SocialMarketer
//
//  Service for managing post history and content retrieval
//

import Foundation
import CoreData

/// Service for managing wisdom content and post history
actor ContentService: ContentServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = ContentService()
    
    // MARK: - Properties
    
    private let rssParser = RSSParser()
    private let logger = Log.content
    
    // MARK: - Public Methods
    
    /// Fetch the daily wisdom entry
    func fetchDaily() async throws -> WisdomEntry? {
        return try await rssParser.fetchDaily()
    }
    
    /// Get a random uncached or least-used entry for posting
    func getNextEntryForPosting() async -> CachedWisdomEntry? {
        return await MainActor.run {
            let context = PersistenceController.shared.viewContext
            let leastUsed = CachedWisdomEntry.fetchLeastUsed(limit: 1, in: context)
            return leastUsed.first
        }
    }
    
    /// Mark an entry as posted
    func markAsPosted(_ entry: CachedWisdomEntry) async {
        await MainActor.run {
            entry.markAsUsed()
            PersistenceController.shared.save()
        }
    }
    
    /// Fetch post history entries (content that has been posted)
    /// - Parameter limit: Maximum number of entries to fetch (0 for unlimited)
    /// - Returns: Array of posted content entries, sorted by most recently posted
    func fetchPostHistory(limit: Int = 0) async -> [CachedWisdomEntry] {
        return await MainActor.run {
            let context = PersistenceController.shared.viewContext
            let request = CachedWisdomEntry.fetchRequest()
            request.predicate = NSPredicate(format: "usedCount > 0")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedWisdomEntry.lastUsedAt, ascending: false)]
            if limit > 0 {
                request.fetchLimit = limit
            }
            
            do {
                return try context.fetch(request)
            } catch {
                logger.error("Failed to fetch post history: \(error.localizedDescription)")
                return []
            }
        }
    }
    
    /// Get total post counts across all history
    /// - Returns: Tuple of (image posts, video posts, total posts)
    func getTotalPostCounts() async -> (images: Int, videos: Int, total: Int) {
        return await MainActor.run {
            let context = PersistenceController.shared.viewContext
            let request = CachedWisdomEntry.fetchRequest()
            request.predicate = NSPredicate(format: "usedCount > 0")
            
            do {
                let entries = try context.fetch(request)
                let totalImages = entries.reduce(0) { $0 + Int($1.postedImageCount) }
                let totalVideos = entries.reduce(0) { $0 + Int($1.postedVideoCount) }
                let totalPosts = entries.reduce(0) { $0 + Int($1.usedCount) }
                return (totalImages, totalVideos, totalPosts)
            } catch {
                logger.error("Failed to fetch post counts: \(error.localizedDescription)")
                return (0, 0, 0)
            }
        }
    }
}

// MARK: - Errors

enum ContentError: LocalizedError {
    case invalidFeedURL
    case fetchFailed(Error)
    case cacheFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFeedURL:
            return "Invalid RSS feed URL configuration"
        case .fetchFailed(let error):
            return "Failed to fetch RSS feed: \(error.localizedDescription)"
        case .cacheFailed:
            return "Failed to cache entries to Core Data"
        }
    }
}
