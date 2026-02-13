//
//  ContentService.swift
//  SocialMarketer
//
//  Orchestrates content fetching, caching, and retrieval from RSS feeds
//

import Foundation
import CoreData

/// Service for managing wisdom content from RSS feeds
actor ContentService {
    
    // MARK: - Singleton
    
    static let shared = ContentService()
    
    // MARK: - Properties
    
    private let rssParser = RSSParser()
    private let logger = Log.content
    
    // MARK: - Public Methods
    
    /// Refresh content from all per-type RSS feeds
    /// Returns the count of new entries added
    @discardableResult
    func refreshContent() async throws -> Int {
        logger.info("Refreshing content from RSS feeds...")
        
        // Fetch from per-type feeds (richer metadata than wisdom.xml)
        let feedKeys = ["thoughts", "quotes", "passages"]
        var allEntries: [WisdomEntry] = []
        
        for key in feedKeys {
            guard let url = RSSParser.feedURLs[key] else { continue }
            do {
                let entries = try await rssParser.fetchFeed(url: url)
                allEntries.append(contentsOf: entries)
            } catch {
                logger.error("Failed to fetch \(key) feed: \(error.localizedDescription)")
                // Continue with other feeds even if one fails
            }
        }
        
        guard !allEntries.isEmpty else {
            throw ContentError.fetchFailed(NSError(domain: "ContentService", code: -1, userInfo: [NSLocalizedDescriptionKey: "All feeds returned empty"]))
        }
        
        logger.info("Fetched \(allEntries.count) total entries from \(feedKeys.count) feeds")
        
        // Cache entries on main actor (Core Data requirement)
        let newCount = await cacheEntries(allEntries)
        logger.info("Cached \(newCount) new entries")
        
        return newCount
    }
    
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
    
    // MARK: - Private Methods
    
    @MainActor
    private func cacheEntries(_ entries: [WisdomEntry]) -> Int {
        let context = PersistenceController.shared.viewContext
        var newCount = 0
        
        for entry in entries {
            // Check for duplicate by link
            let linkString = entry.link.absoluteString
            if let existing = CachedWisdomEntry.findByLink(linkString, in: context) {
                // Update existing entry content (picks up improved cleaning)
                existing.title = entry.title
                existing.content = entry.content
                existing.reference = entry.reference
                continue
            }
            
            // Create new cached entry
            let _ = CachedWisdomEntry(context: context, from: entry)
            newCount += 1
        }
        
        // Always save (updates existing + inserts new)
        PersistenceController.shared.save()
        
        return newCount
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
