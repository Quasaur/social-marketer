//
//  PostingAnalytics.swift
//  Social Marketer
//
//  Provides posting statistics and analytics
//

import Foundation
import CoreData
import SwiftUI
import Combine

/// Statistics for a single platform
struct PlatformStats: Identifiable {
    let id = UUID()
    let name: String
    let totalAttempts: Int
    let successCount: Int
    let failureCount: Int
    
    var successRate: Double {
        totalAttempts > 0 ? Double(successCount) / Double(totalAttempts) * 100 : 0
    }
}

/// Overall posting statistics
struct PostingStats {
    let totalPosts: Int
    let totalAttempts: Int
    let successCount: Int
    let failureCount: Int
    let platformStats: [PlatformStats]
    let topErrors: [(error: String, count: Int)]
    
    var successRate: Double {
        totalAttempts > 0 ? Double(successCount) / Double(totalAttempts) * 100 : 0
    }
    
    var averagePostsPerDay: Double {
        guard totalPosts > 0 else { return 0 }
        // This is a placeholder - would need oldest post date for accurate calculation
        return Double(totalPosts) / 30.0
    }
}

/// Service for retrieving posting analytics
@MainActor
class PostingAnalytics: ObservableObject {
    private let context: NSManagedObjectContext
    
    @Published var currentStats: PostingStats?
    @Published var isLoading = false
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Fetch statistics for a given time period
    func fetchStats(period: StatsPeriod = .allTime) async {
        isLoading = true
        defer { isLoading = false }
        
        let startDate = period.startDate
        
        // Fetch all post logs
        let request = PostLog.fetchRequest()
        if let startDate = startDate {
            request.predicate = NSPredicate(format: "timestamp >= %@", startDate as NSDate)
        }
        
        do {
            let logs = try context.fetch(request)
            
            // Calculate overall stats
            let totalAttempts = logs.count
            let successCount = logs.filter { $0.success }.count
            let failureCount = totalAttempts - successCount
            
            // Get unique posts
            let uniquePosts = Set(logs.compactMap { $0.post?.id })
            let totalPosts = uniquePosts.count
            
            // Calculate per-platform stats
            let platformStats = calculatePlatformStats(from: logs)
            
            // Get top errors
            let topErrors = calculateTopErrors(from: logs)
            
            currentStats = PostingStats(
                totalPosts: totalPosts,
                totalAttempts: totalAttempts,
                successCount: successCount,
                failureCount: failureCount,
                platformStats: platformStats,
                topErrors: topErrors
            )
        } catch {
            Log.app.error("Failed to fetch posting stats: \(error.localizedDescription)")
            currentStats = PostingStats(
                totalPosts: 0,
                totalAttempts: 0,
                successCount: 0,
                failureCount: 0,
                platformStats: [],
                topErrors: []
            )
        }
    }
    
    private func calculatePlatformStats(from logs: [PostLog]) -> [PlatformStats] {
        // Group logs by platform
        let grouped = Dictionary(grouping: logs) { $0.platform?.name ?? "Unknown" }
        
        return grouped.map { (platformName, platformLogs) in
            let successCount = platformLogs.filter { $0.success }.count
            let totalAttempts = platformLogs.count
            let failureCount = totalAttempts - successCount
            
            return PlatformStats(
                name: platformName,
                totalAttempts: totalAttempts,
                successCount: successCount,
                failureCount: failureCount
            )
        }.sorted { $0.name < $1.name }
    }
    
    private func calculateTopErrors(from logs: [PostLog]) -> [(error: String, count: Int)] {
        let failedLogs = logs.filter { !$0.success }
        let grouped = Dictionary(grouping: failedLogs) { $0.errorMessage ?? "Unknown error" }
        
        return grouped
            .map { (error, logs) in (error: error, count: logs.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
}

/// Time period for statistics
enum StatsPeriod {
    case last7Days
    case last30Days
    case allTime
    
    var startDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: Date())
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: Date())
        case .allTime:
            return nil
        }
    }
    
    var displayName: String {
        switch self {
        case .last7Days: return "Last 7 Days"
        case .last30Days: return "Last 30 Days"
        case .allTime: return "All Time"
        }
    }
}
