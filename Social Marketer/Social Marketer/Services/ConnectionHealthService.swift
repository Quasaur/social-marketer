//
//  ConnectionHealthService.swift
//  SocialMarketer
//
//  Lightweight startup health checks for all external dependencies
//

import Foundation
import Combine

/// Result of a single connection probe
struct ConnectionResult: Identifiable {
    let id = UUID()
    let name: String
    let category: ConnectionCategory
    let url: URL
    let reachable: Bool
    let latencyMs: Int?      // nil if unreachable
    let checkedAt: Date
    
    enum ConnectionCategory: String, CaseIterable {
        case contentSource = "Content Source"
        case socialMedia = "Social Media"
        case searchEngines = "Search Engines"
        case webDirectories = "Web Directories"
        case rssAggregators = "RSS Aggregators"
        
        var icon: String {
            switch self {
            case .contentSource:   return "book.fill"
            case .socialMedia:     return "bubble.left.and.bubble.right.fill"
            case .searchEngines:   return "magnifyingglass.circle.fill"
            case .webDirectories:  return "folder.fill"
            case .rssAggregators:  return "dot.radiowaves.up.forward"
            }
        }
        
        var color: String {
            switch self {
            case .contentSource:   return "teal"
            case .socialMedia:     return "blue"
            case .searchEngines:   return "green"
            case .webDirectories:  return "orange"
            case .rssAggregators:  return "purple"
            }
        }
    }
}

/// Probes external endpoints at startup to verify reachability
@MainActor
final class ConnectionHealthService: ObservableObject {
    
    @Published var results: [ConnectionResult] = []
    @Published var isChecking = false
    
    /// All external endpoints grouped by category
    private static let endpoints: [(name: String, category: ConnectionResult.ConnectionCategory, url: String)] = [
        // Content Source
        ("Wisdom Book",       .contentSource,   "https://www.wisdombook.life"),
        
        // Social Media
        ("X (Twitter)",       .socialMedia,      "https://api.twitter.com"),
        ("Meta (IG & FB)",    .socialMedia,      "https://graph.facebook.com"),
        ("LinkedIn",          .socialMedia,      "https://api.linkedin.com"),
        ("Pinterest",         .socialMedia,      "https://api.pinterest.com"),
        
        // Search Engines
        ("Google",            .searchEngines,    "https://www.googleapis.com"),
        ("Bing",              .searchEngines,    "https://www.bing.com"),
        
        // Web Directories
        ("Curlie",            .webDirectories,   "https://curlie.org"),
        ("Jasmine Directory", .webDirectories,   "https://www.jasminedirectory.com"),
        
        // RSS Aggregators
        ("Feedly",            .rssAggregators,   "https://feedly.com"),
        ("Inoreader",         .rssAggregators,   "https://www.inoreader.com"),
        ("NewsBlur",          .rssAggregators,   "https://newsblur.com"),
    ]
    
    /// Run all health checks concurrently
    func checkAll() async {
        isChecking = true
        
        let probeResults = await withTaskGroup(of: ConnectionResult.self, returning: [ConnectionResult].self) { group in
            for endpoint in Self.endpoints {
                group.addTask {
                    await self.probe(name: endpoint.name, category: endpoint.category, urlString: endpoint.url)
                }
            }
            
            var collected: [ConnectionResult] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }
        
        // Sort by category order, then by name
        let categoryOrder = ConnectionResult.ConnectionCategory.allCases
        results = probeResults.sorted { a, b in
            let aIdx = categoryOrder.firstIndex(of: a.category) ?? 0
            let bIdx = categoryOrder.firstIndex(of: b.category) ?? 0
            if aIdx != bIdx { return aIdx < bIdx }
            return a.name < b.name
        }
        
        isChecking = false
    }
    
    /// Number of unreachable endpoints
    var issueCount: Int {
        results.filter { !$0.reachable }.count
    }
    
    // MARK: - Private
    
    /// HTTP HEAD probe with a short timeout
    nonisolated private func probe(name: String, category: ConnectionResult.ConnectionCategory, urlString: String) async -> ConnectionResult {
        guard let url = URL(string: urlString) else {
            return ConnectionResult(name: name, category: category, url: URL(string: "https://invalid")!, reachable: false, latencyMs: nil, checkedAt: Date())
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        
        let start = Date()
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            
            if let http = response as? HTTPURLResponse {
                // Any HTTP response (even 4xx) means the host is reachable
                let reachable = http.statusCode < 500
                return ConnectionResult(name: name, category: category, url: url, reachable: reachable, latencyMs: latency, checkedAt: Date())
            }
            
            return ConnectionResult(name: name, category: category, url: url, reachable: true, latencyMs: latency, checkedAt: Date())
        } catch {
            return ConnectionResult(name: name, category: category, url: url, reachable: false, latencyMs: nil, checkedAt: Date())
        }
    }
}
