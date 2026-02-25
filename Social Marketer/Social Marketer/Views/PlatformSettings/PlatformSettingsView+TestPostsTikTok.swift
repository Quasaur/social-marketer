//
//  PlatformSettingsView+TestPostsTikTok.swift
//  SocialMarketer
//
//  TikTok test post method for PlatformSettingsView
//  Uses the scheduled post for the day from the queue
//

import SwiftUI

extension PlatformSettingsView {
    
    @MainActor
    func testTikTokPost() async {
        await testManager.performTest(platform: "tiktok") {
            Log.app.info("[TikTok] Test Post started - Using scheduled post from queue...")
            
            let connector = TikTokConnector()
            guard await connector.isConfigured else {
                return TestPostResult(
                    success: false,
                    message: "TikTok not configured. Please connect your TikTok account first.",
                    postURL: nil
                )
            }
            
            let context = PersistenceController.shared.viewContext
            guard let tiktokPlatform = Platform.find(name: "TikTok", in: context) else {
                return TestPostResult(
                    success: false,
                    message: "TikTok platform not found in database.",
                    postURL: nil
                )
            }
            
            // Get the scheduled post for today
            guard let scheduledPost = await getScheduledPostForToday(),
                  let content = scheduledPost.content else {
                return TestPostResult(
                    success: false,
                    message: "No scheduled post available. Check Post Queue.",
                    postURL: nil
                )
            }
            
            let title = content.prefix(60).replacingOccurrences(of: "\n", with: " ")
            let link = scheduledPost.link ?? URL(string: "https://wisdombook.life")!
            
            let caption = content
            let result: PostResult
            
            // TikTok only supports video (no images)
            Log.app.info("[TikTok] Test Post - Generating video for: \(title)")
            
            // Ensure Social Effects server is running
            Log.app.info("[TikTok] Ensuring Social Effects server is running...")
            let serverReady = await SocialEffectsService.shared.ensureServerRunning()
            guard serverReady else {
                let errorMsg = "Social Effects video server is not available. Please ensure it's installed at ~/Developer/social-effects/"
                ErrorLog.shared.log(category: "TikTok", message: "Video server unavailable", detail: errorMsg)
                return TestPostResult(
                    success: false,
                    message: errorMsg,
                    postURL: nil
                )
            }
            Log.app.info("[TikTok] Social Effects server ready")
            
            if let existingVideoURL = await findExistingVideo(for: String(title)) {
                Log.app.info("[TikTok] Test Post - Using existing video: \(existingVideoURL.lastPathComponent)")
                result = try await connector.postVideo(existingVideoURL, caption: caption)
            } else {
                Log.app.info("[TikTok] Test Post - Generating new video for: \(title)")
                
                let videoGen = VideoGenerator()
                let entry = WisdomEntry(
                    id: UUID(),
                    title: String(title),
                    content: content,
                    reference: nil,
                    link: link,
                    pubDate: Date(),
                    category: .thought
                )
                
                do {
                    guard let videoURL = try await videoGen.generateVideo(entry: entry) else {
                        let errorMsg = "Video generation failed - no output file"
                        ErrorLog.shared.log(category: "TikTok", message: "Video generation failed", detail: errorMsg)
                        return TestPostResult(
                            success: false,
                            message: errorMsg,
                            postURL: nil
                        )
                    }
                    Log.app.info("[TikTok] Video generated: \(videoURL.lastPathComponent)")
                    result = try await connector.postVideo(videoURL, caption: caption)
                } catch let error as VideoGenerationError {
                    let errorMsg = error.localizedDescription
                    ErrorLog.shared.log(category: "TikTok", message: "Video generation error", detail: errorMsg)
                    return TestPostResult(
                        success: false,
                        message: "Video generation failed: \(errorMsg)",
                        postURL: nil
                    )
                }
            }
            
            if result.success {
                return TestPostResult(
                    success: true,
                    message: "Posted scheduled content to TikTok! 🎉",
                    postURL: result.postURL
                )
            } else {
                let errorMsg = result.error?.localizedDescription ?? "Unknown error"
                ErrorLog.shared.log(category: "TikTok", message: "Test post failed", detail: errorMsg)
                return TestPostResult(
                    success: false,
                    message: "Failed to post: \(errorMsg)",
                    postURL: nil
                )
            }
        }
    }
}
