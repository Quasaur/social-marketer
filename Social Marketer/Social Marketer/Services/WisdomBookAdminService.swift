import Foundation

/// Service for fetching admin data from Wisdom Book backend
class WisdomBookAdminService {
    
    // MARK: - Properties
    
    /// Admin API token for authentication
    private let adminToken = "9Rae4NVLhKz8yJ2xPwQmTn5FvBc6GsHtDk7UiWoA3Xe"
    
    /// Base URL for Wisdom Book API
    private let baseURL = "https://www.wisdombook.life/api/users"
    
    // MARK: - Models
    
    struct Member: Codable, Identifiable {
        let id: Int
        let username: String
        let nickname: String?
        let email: String
        let dateJoined: String
        let kofiBadge: String
        let isGuardian: Bool
        
        enum CodingKeys: String, CodingKey {
            case id, username, nickname, email
            case dateJoined = "date_joined"
            case kofiBadge = "kofi_badge"
            case isGuardian = "is_guardian"
        }
        
        var displayName: String {
            nickname ?? username
        }
        
        var joinedDate: Date? {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: dateJoined)
        }
    }
    
    struct LinkedUser: Codable {
        let username: String
        let nickname: String?
        
        var displayName: String {
            nickname ?? username
        }
    }
    
    struct KofiTip: Codable, Identifiable {
        let id: Int
        let fromName: String
        let amount: String
        let currency: String
        let type: String
        let isSubscription: Bool
        let tierName: String?
        let timestamp: String
        let message: String?
        let linkedUser: LinkedUser?
        
        enum CodingKeys: String, CodingKey {
            case id
            case fromName = "from_name"
            case amount, currency, type
            case isSubscription = "is_subscription"
            case tierName = "tier_name"
            case timestamp, message
            case linkedUser = "linked_user"
        }
        
        var tipDate: Date? {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: timestamp)
        }
        
        var amountValue: Double {
            Double(amount) ?? 0.0
        }
    }
    
    struct MembersResponse: Codable {
        let count: Int
        let days: Int
        let members: [Member]
    }
    
    struct TipsResponse: Codable {
        let count: Int
        let days: Int
        let tips: [KofiTip]
    }
    
    struct UserStats: Codable {
        let total: Int
        let last7Days: Int
        let last30Days: Int
        
        enum CodingKeys: String, CodingKey {
            case total
            case last7Days = "last_7_days"
            case last30Days = "last_30_days"
        }
    }
    
    struct KofiStats: Codable {
        let total: Int
        let last7Days: Int
        let last30Days: Int
        let activeSubscriptions: Int
        
        enum CodingKeys: String, CodingKey {
            case total
            case last7Days = "last_7_days"
            case last30Days = "last_30_days"
            case activeSubscriptions = "active_subscriptions"
        }
    }
    
    struct RevenueStats: Codable {
        let last30Days: String
        let currency: String
        
        enum CodingKeys: String, CodingKey {
            case last30Days = "last_30_days"
            case currency
        }
        
        var amountValue: Double {
            Double(last30Days) ?? 0.0
        }
    }
    
    struct ActivitySummary: Codable {
        let users: UserStats
        let kofiTips: KofiStats
        let revenue: RevenueStats
        let generatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case users
            case kofiTips = "kofi_tips"
            case revenue
            case generatedAt = "generated_at"
        }
    }
    
    // MARK: - API Methods
    
    /// Fetch recent members from Wisdom Book
    func fetchRecentMembers(days: Int = 30) async throws -> MembersResponse {
        let url = URL(string: "\(baseURL)/admin-api/recent-members/?days=\(days)")!
        var request = URLRequest(url: url)
        request.addValue(adminToken, forHTTPHeaderField: "X-Admin-Token")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(MembersResponse.self, from: data)
    }
    
    /// Fetch recent Ko-fi tips from Wisdom Book
    func fetchRecentTips(days: Int = 30) async throws -> TipsResponse {
        let url = URL(string: "\(baseURL)/admin-api/recent-kofi-tips/?days=\(days)")!
        var request = URLRequest(url: url)
        request.addValue(adminToken, forHTTPHeaderField: "X-Admin-Token")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(TipsResponse.self, from: data)
    }
    
    /// Fetch activity summary from Wisdom Book
    func fetchActivitySummary() async throws -> ActivitySummary {
        let url = URL(string: "\(baseURL)/admin-api/activity-summary/")!
        var request = URLRequest(url: url)
        request.addValue(adminToken, forHTTPHeaderField: "X-Admin-Token")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ActivitySummary.self, from: data)
    }
}
