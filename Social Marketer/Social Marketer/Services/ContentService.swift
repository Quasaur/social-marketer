//
//  ContentService.swift
//  SocialMarketer
//
//  Orchestrates content fetching, caching, and retrieval from RSS feeds
//

import Foundation
import CoreData
import os.log

/// Service for managing wisdom content from RSS feeds
actor ContentService {
    
    // MARK: - Singleton
    
    static let shared = ContentService()
    
    // MARK: - Properties
    
    private let rssParser = RSSParser()
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "ContentService")
    
    // MARK: - Public Methods
    
    /// Refresh content from the main wisdom feed
    /// Returns the count of new entries added
    @discardableResult
    func refreshContent() async throws -> Int {
        logger.info("Refreshing content from RSS feed...")
        
        // Fetch from the main wisdom feed
        guard let feedURL = RSSParser.feedURLs["wisdom"] else {
            throw ContentError.invalidFeedURL
        }
        
        let entries = try await rssParser.fetchFeed(url: feedURL)
        logger.info("Fetched \(entries.count) entries from RSS feed")
        
        // Cache entries on main actor (Core Data requirement)
        let newCount = await cacheEntries(entries)
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
            if CachedWisdomEntry.findByLink(linkString, in: context) != nil {
                continue // Skip duplicates
            }
            
            // Create new cached entry
            let _ = CachedWisdomEntry(context: context, from: entry)
            newCount += 1
        }
        
        if newCount > 0 {
            PersistenceController.shared.save()
        }
        
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
