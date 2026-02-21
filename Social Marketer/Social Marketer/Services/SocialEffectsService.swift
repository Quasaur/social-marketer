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
/// Manages the complete lifecycle: start server → generate video → shutdown server
class SocialEffectsService {
    static let shared = SocialEffectsService()
    
    private let processManager = SocialEffectsProcessManager.shared
    private let baseURL = "http://localhost:5390"
    private let timeout: TimeInterval = 300 // 5 minutes for video generation
    
    private init() {}
    
    /// Executes the complete video generation workflow
    /// - Parameter rssItem: The RSS item to convert to video
    /// - Returns: Path to the generated video file
    /// - Throws: SocialEffectsError if any step fails
    func generateVideo(from rssItem: RSSItem) async throws -> String {
        // Step 1: Start the server
        let serverStarted = try await processManager.startServer()
        guard serverStarted else {
            throw SocialEffectsError.serverStartFailed
        }
        
        // Step 2: Verify health
        let healthy = await processManager.checkHealth()
        guard healthy else {
            throw SocialEffectsError.serverNotRunning
        }
        
        // Step 3: Generate video
        let videoPath = try await sendGenerationRequest(
            title: rssItem.title,
            content: rssItem.content,
            contentType: rssItem.contentType,
            nodeTitle: rssItem.nodeTitle
        )
        
        return videoPath
    }
    
    /// Shuts down the Social Effects server
    /// Call this after video generation is complete
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
            "ping_pong": false
        ]
        
        // Debug logging (when Debug Mode enabled)
        if Log.isDebugMode {
            Log.debug("Request body dict: \(body)", category: "SocialEffects")
        }
        
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: body)
            if Log.isDebugMode {
                Log.debug("JSON data size: \(jsonData.count) bytes", category: "SocialEffects")
            }
        } catch {
            Log.debug("JSON serialization failed: \(error)", category: "SocialEffects")
            throw SocialEffectsError.generationFailed("JSON serialization failed: \(error.localizedDescription)")
        }
        
        // Debug: Log the JSON being sent (when Debug Mode enabled)
        if Log.isDebugMode, let jsonString = String(data: jsonData, encoding: .utf8) {
            Log.debug("Sending JSON: \(jsonString)", category: "SocialEffects")
        }
        
        request.httpBody = jsonData
        request.setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        
        print("✅ Video generated: \(videoPath)")
        return videoPath
    }
    
    /// Executes the full workflow and automatically shuts down server
    /// - Parameter rssItem: The RSS item to convert
    /// - Returns: Path to generated video
    func executeFullWorkflow(from rssItem: RSSItem) async throws -> String {
        if Log.isDebugMode {
            Log.debug("executeFullWorkflow called - title: \(rssItem.title), contentType: \(rssItem.contentType)", category: "SocialEffects")
        }
        
        defer {
            // Ensure server is always shut down, even on error
            Task {
                await shutdown()
            }
        }
        
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
