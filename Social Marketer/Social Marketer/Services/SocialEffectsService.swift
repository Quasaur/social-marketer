import Foundation

/// Errors that can occur during Social Effects operations
enum SocialEffectsError: Error {
    case serverStartFailed
    case serverNotRunning
    case generationFailed(String)
    case invalidResponse
    case timeout
}

/// Service for generating videos via Social Effects API
/// The server is started when Social Marketer launches and runs continuously
/// until the app shuts down (see AppDelegate for shutdown handling)
class SocialEffectsService {
    static let shared = SocialEffectsService()
    
    private let processManager = SocialEffectsProcessManager.shared
    private let baseURL = "http://localhost:5390"
    private let timeout: TimeInterval = 300 // 5 minutes for video generation
    
    /// Dedicated URLSession with extended timeout for video generation
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout  // 5 minutes total
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    /// Maximum time to wait for video generation (8 minutes)
    private let generationTimeout: TimeInterval = 480
    
    private init() {}
    
    /// Ensures the Social Effects server is running
    /// Called on app launch to start the persistent service
    /// - Returns: True if server is running (started or already running)
    @discardableResult
    func ensureServerRunning() async -> Bool {
        if await processManager.serverIsRunning {
            return true
        }
        
        do {
            return try await processManager.startServer()
        } catch {
            Log.app.error("Failed to start Social Effects: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Generates a video using the running Social Effects server
    /// - Parameter rssItem: The RSS item to convert to video
    /// - Returns: Path to the generated video file
    /// - Throws: SocialEffectsError if any step fails
    func generateVideo(from rssItem: RSSItem) async throws -> String {
        // Ensure server is running (idempotent)
        let serverRunning = await ensureServerRunning()
        guard serverRunning else {
            throw SocialEffectsError.serverStartFailed
        }
        
        // Generate video with timeout
        return try await withTimeout(seconds: generationTimeout) {
            try await self.sendGenerationRequest(
                title: rssItem.title,
                content: rssItem.content,
                contentType: rssItem.contentType,
                nodeTitle: rssItem.nodeTitle
            )
        }
    }
    
    /// Execute a task with a timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual work
            group.addTask {
                try await operation()
            }
            
            // Add the timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw SocialEffectsError.generationFailed("Video generation timed out after \(Int(seconds)) seconds")
            }
            
            // Return the first result or throw
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// Shuts down the Social Effects server
    /// Called when Social Marketer is shutting down
    func shutdown() async {
        await processManager.shutdownServer()
    }
    
    /// Sends the video generation request to the API
    private func sendGenerationRequest(
        title: String,
        content: String,
        contentType: String,
        nodeTitle: String
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/generate") else {
            throw SocialEffectsError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        
        let body: [String: Any] = [
            "title": title,
            "content": content,
            "content_type": contentType,
            "node_title": nodeTitle,
            "ping_pong": true
        ]
        
        // Always log the request for debugging
        print("[SocialEffects] Request body dict: \(body)")
        
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: body)
            print("[SocialEffects] JSON data size: \(jsonData.count) bytes")
        } catch {
            print("[SocialEffects] JSON serialization failed: \(error)")
            throw SocialEffectsError.generationFailed("JSON serialization failed: \(error.localizedDescription)")
        }
        
        // Log the JSON being sent
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("[SocialEffects] Sending JSON: \(jsonString)")
        }
        
        request.httpBody = jsonData
        request.setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
        
        // Retry logic for transient network errors
        let maxRetries = 2
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SocialEffectsError.invalidResponse
                }
                
                guard httpResponse.statusCode == 200 else {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw SocialEffectsError.generationFailed("HTTP \(httpResponse.statusCode): \(errorBody)")
                }
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw SocialEffectsError.invalidResponse
                }
                
                guard let success = json["success"] as? Bool, success == true else {
                    let errorMessage = json["error"] as? String ?? "Unknown error"
                    throw SocialEffectsError.generationFailed(errorMessage)
                }
                
                guard let videoPath = json["video_path"] as? String else {
                    throw SocialEffectsError.invalidResponse
                }
                
                if Log.isDebugMode {
                    Log.debug("Video generated: \(videoPath)", category: "SocialEffects")
                }
                return videoPath
                
            } catch {
                lastError = error
                if attempt < maxRetries {
                    print("⚠️ Video generation attempt \(attempt) failed: \(error.localizedDescription). Retrying...")
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000) // 2s, 4s backoff
                }
            }
        }
        
        throw lastError ?? SocialEffectsError.generationFailed("All retry attempts failed")
    }
    
    /// Legacy method - now just calls generateVideo
    /// Server lifecycle is managed at app level, not per-video
    /// - Parameter rssItem: The RSS item to convert
    /// - Returns: Path to generated video
    func executeFullWorkflow(from rssItem: RSSItem) async throws -> String {
        if Log.isDebugMode {
            Log.debug("executeFullWorkflow called - title: \(rssItem.title), contentType: \(rssItem.contentType)", category: "SocialEffects")
        }
        
        // Server stays running - shutdown is handled at app termination
        return try await generateVideo(from: rssItem)
    }
}

/// Represents an RSS item from wisdombook.life
struct RSSItem {
    let title: String
    let content: String
    let contentType: String
    let nodeTitle: String
    let source: String
    let pubDate: Date
}
