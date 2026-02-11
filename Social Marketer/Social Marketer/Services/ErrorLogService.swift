//
//  ErrorLogService.swift
//  SocialMarketer
//
//  In-memory error log for surfacing recent errors in the UI.
//  Also forwards to ULS (os.log) so Console.app visibility is preserved.
//

import Foundation
import Combine

/// A single error log entry
struct ErrorEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let category: String
    let message: String
    let detail: String?
}

/// In-memory error log, capped at 100 most-recent entries.
///
/// Usage:  `ErrorLog.shared.log(category: "RSS", message: "Feed fetch failed", detail: error.localizedDescription)`
@MainActor
final class ErrorLog: ObservableObject {
    
    static let shared = ErrorLog()
    
    /// Maximum entries retained in memory
    static let maxEntries = 100
    
    @Published private(set) var entries: [ErrorEntry] = []
    
    /// Number of unread errors since last clear
    var count: Int { entries.count }
    
    private init() {}
    
    // MARK: - Public API
    
    /// Record an error and forward it to ULS.
    func log(category: String, message: String, detail: String? = nil) {
        let entry = ErrorEntry(
            timestamp: Date(),
            category: category,
            message: message,
            detail: detail
        )
        
        entries.insert(entry, at: 0)  // newest first
        
        // Trim to cap
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        
        // Forward to ULS
        Log.app.error("[\(category)] \(message)\(detail.map { " — \($0)" } ?? "")")
    }
    
    /// Clear all logged errors.
    func clear() {
        entries.removeAll()
    }
}
