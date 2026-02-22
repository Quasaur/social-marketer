//
//  VideoGenerator.swift
//  SocialMarketer
//
//  Generates videos by integrating with SocialEffects HTTP API.
//  Updated to use API server instead of direct CLI invocation.
//

import Foundation

/// Generates videos using the SocialEffects HTTP API.
/// Server lifecycle is managed at app level (started on launch, stopped on quit).
/// This class simply uses the running server for video generation requests.
@MainActor
final class VideoGenerator {
    
    private let logger = Log.scheduler
    private let socialEffectsService = SocialEffectsService.shared
    
    /// Generates a video for the entry using SocialEffects API
    /// - Parameter entry: The wisdom entry to convert to video
    /// - Returns: URL to the generated video file, or nil if generation failed
    func generateVideo(entry: WisdomEntry) async throws -> URL? {
        logger.info("🎬 Starting video generation via SocialEffects API...")
        
        // Convert WisdomEntry to RSSItem format expected by API
        let rssItem = RSSItem(
            title: entry.title,
            content: entry.content,
            contentType: entry.category.rawValue.lowercased(),
            nodeTitle: sanitizeTitle(entry.title),
            source: entry.reference ?? AppConfiguration.URLs.wisdomBookDomain,
            pubDate: entry.pubDate
        )
        
        do {
            // Use the full workflow that manages server lifecycle
            let videoPath = try await socialEffectsService.executeFullWorkflow(from: rssItem)
            
            logger.info("✅ Video generated at: \(videoPath)")
            return URL(fileURLWithPath: videoPath)
            
        } catch SocialEffectsError.serverStartFailed {
            logger.error("❌ Failed to start SocialEffects server")
            throw VideoGenerationError.serverUnavailable
        } catch SocialEffectsError.serverNotRunning {
            logger.error("❌ SocialEffects server not responding")
            throw VideoGenerationError.serverUnavailable
        } catch SocialEffectsError.generationFailed(let message) {
            logger.error("❌ Video generation failed: \(message)")
            throw VideoGenerationError.generationFailed(message)
        } catch {
            logger.error("❌ Unexpected error: \(error.localizedDescription)")
            throw VideoGenerationError.unknown(error)
        }
    }
    
    /// Legacy method - now behaves the same as generateVideo
    /// Server lifecycle is managed at app level, not per-generation
    func generateVideoWithManualLifecycle(entry: WisdomEntry) async throws -> URL? {
        logger.info("🎬 Video generation (using persistent server)...")
        // Server stays running - same as generateVideo now
        return try await generateVideo(entry: entry)
    }
    
    /// Get the next border style in the rotation
    /// Cycles through all available ornate styles for visual variety.
    func getNextBorderStyle() -> String {
        let styles = [
            "gold", "silver", "minimal",
            "art-deco", "classic-scroll", "sacred-geometry",
            "celtic-knot", "fleur-de-lis", "baroque",
            "victorian", "golden-vine", "stained-glass", "modern-glow"
        ]
        let key = "lastUsedBorderStyle"
        let last = UserDefaults.standard.string(forKey: key)
        
        // Find next style
        let next: String
        if let last = last, let index = styles.firstIndex(of: last) {
            next = styles[(index + 1) % styles.count]
        } else {
            next = "gold" // Default first style
        }
        
        // Save
        UserDefaults.standard.set(next, forKey: key)
        logger.info("🎨 Next video border style: \(next)")
        return next
    }
    
    /// Sanitizes a title for use as a node name
    /// Converts to Initial_Caps_With_Underscores format
    private func sanitizeTitle(_ title: String) -> String {
        // Remove special characters, keep alphanumeric and spaces
        let allowedChars = CharacterSet.alphanumerics.union(.whitespaces)
        let sanitized = title.components(separatedBy: allowedChars.inverted).joined(separator: " ")
        
        // Split by whitespace and capitalize each word
        let words = sanitized.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        let capitalizedWords = words.map { word in
            let first = word.prefix(1).uppercased()
            let rest = word.dropFirst().lowercased()
            return first + rest
        }
        
        return capitalizedWords.joined(separator: "_")
    }
}

/// Errors that can occur during video generation
enum VideoGenerationError: Error {
    case serverUnavailable
    case generationFailed(String)
    case unknown(Error)
}
