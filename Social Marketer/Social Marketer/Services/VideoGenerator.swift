//
//  VideoGenerator.swift
//  SocialMarketer
//
//  Invokes the SocialEffects CLI to generate videos for wisdom entries.
//  Extracted from PostScheduler.swift to follow Single Responsibility Principle.
//

import Foundation

/// Generates videos by invoking the SocialEffects CLI tool.
@MainActor
final class VideoGenerator {
    
    private let logger = Log.scheduler
    
    /// Invokes the SocialEffects CLI to generate a video for the entry
    func generateVideo(entry: WisdomEntry) async throws -> URL? {
        logger.info("🎬 invoking SocialEffects generate-video...")
        
        let process = Process()
        // Assume 'SocialEffects' is in the path or build dir.
        // For development, valid path to executable is required.
        // We'll try a few common locations or assume it's in a known dev path.
        // Ideally this should be a bundled XPC service, but for CLI integration:
        let possiblePaths = [
            "/Users/quasaur/Developer/social-effects/.build/debug/SocialEffects",
            "/usr/local/bin/SocialEffects"
        ]
        
        guard let executablePath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            logger.error("SocialEffects executable not found. Build it first.")
            return nil
        }
        
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = [
            "generate-video",
            "--title", entry.title,
            "--content", entry.content,
            "--source", entry.reference ?? "wisdombook.life",
            "--background", "auto", // implementation handles rotation
            "--border", getNextBorderStyle(),
            "--output-json"
        ]
        
        // Pass environment variables (API Keys)
        process.environment = ProcessInfo.processInfo.environment
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        
        if process.terminationStatus == 0, let output = String(data: data, encoding: .utf8) {
            // Parse JSON output
            // Expected: { "success": true, "videoPath": "..." }
            if let jsonData = output.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let path = json["videoPath"] as? String {
                
                logger.info("✅ Video generated at: \(path)")
                return URL(fileURLWithPath: path)
            }
        }
        
        logger.error("Video generation failed or invalid output")
        if let errOut = String(data: data, encoding: .utf8) {
             logger.error("Output: \(errOut)")
        }
        return nil
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
}
