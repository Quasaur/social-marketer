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
    
    /// Refresh content from the main wisdom feed
    /// Returns the count of new entries added
    @discardableResult
    func refreshContent() async throws -> Int {
        let startTime = Date()
        logger.info("Refreshing content from RSS feed...")
        
        // Fetch from the main wisdom feed
        guard let feedURL = RSSParser.feedURLs["wisdom"] else {
            throw ContentError.invalidFeedURL
        }
        
        let fetchStart = Date()
        let entries = try await rssParser.fetchFeed(url: feedURL)
        let fetchTime = Date().timeIntervalSince(fetchStart)
        logger.info("Fetched \(entries.count) entries in \(String(format: "%.2f", fetchTime))s")
        
        // Cache entries on main actor (Core Data requirement)
        let cacheStart = Date()
        let newCount = await cacheEntries(entries)
        let cacheTime = Date().timeIntervalSince(cacheStart)
        logger.info("Cached \(newCount) new entries in \(String(format: "%.2f", cacheTime))s")
        
        let totalTime = Date().timeIntervalSince(startTime)
        logger.info("Total refresh time: \(String(format: "%.2f", totalTime))s")
        
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
        
        // Batch fetch all existing entries by link (single query instead of 50!)
        let linkStrings = entries.map { $0.link.absoluteString }
        let request = CachedWisdomEntry.fetchRequest()
        request.predicate = NSPredicate(format: "linkString IN %@", linkStrings)
        
        let existingEntries: [CachedWisdomEntry]
        do {
            existingEntries = try context.fetch(request)
        } catch {
            logger.error("Failed to fetch existing entries: \(error.localizedDescription)")
            existingEntries = []
        }
        
        // Build lookup dictionary for O(1) access
        let existingByLink: [String: CachedWisdomEntry] = Dictionary(uniqueKeysWithValues: existingEntries.compactMap { entry in
            guard let link = entry.linkString else { return nil }
            return (link, entry)
        })
        
        for entry in entries {
            let linkString = entry.link.absoluteString
            if let existing = existingByLink[linkString] {
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
