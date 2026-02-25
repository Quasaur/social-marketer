//
//  PlatformSettingsView+TestPostsPinterestYouTube.swift
//  SocialMarketer
//
//  Pinterest and YouTube test post methods for PlatformSettingsView
//  Uses the scheduled post for the day from the queue
//

import SwiftUI

extension PlatformSettingsView {
    
    // MARK: - Pinterest Test Post
    
    @MainActor
    func testPinterestPost() async {
        await testManager.performTest(platform: "pinterest") {
            let connector = PinterestConnector()
            if !(await connector.isConfigured) {
                if let _ = try? OAuthManager.shared.getTokens(for: "pinterest") {
                    return TestPostResult(
                        success: false,
                        message: "Pinterest board not configured. Please Disconnect and Connect Pinterest again to auto-discover your boards.",
                        postURL: nil
                    )
                }
            }
            guard await connector.isConfigured else {
                return TestPostResult(
                    success: false,
                    message: "Pinterest not configured. Try disconnecting and reconnecting.",
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
            
            let link = scheduledPost.link ?? URL(string: "https://www.wisdombook.life")!
            
            let captionBuilder = CaptionBuilder()
            let entry = WisdomEntry(
                id: UUID(),
                title: String(content.prefix(60)),
                content: content,
                reference: nil,
                link: link,
                pubDate: Date(),
                category: .thought
            )
            let caption = captionBuilder.buildCaption(from: entry)
            
            // Generate graphic for the scheduled content
            let generator = QuoteGraphicGenerator()
            guard let image = generator.generate(from: entry) else {
                return TestPostResult(
                    success: false,
                    message: "Could not generate image for Pinterest pin.",
                    postURL: nil
                )
            }
            
            let result = try await connector.post(image: image, caption: caption, link: link)
            return TestPostResult(
                success: result.success,
                message: result.success ? "Pinned scheduled content to Pinterest! 📌" : (result.error?.localizedDescription ?? "Pinterest post failed"),
                postURL: result.postURL
            )
        }
    }
    
    // MARK: - YouTube Test Post
    
    @MainActor
    func testYouTubePost() async {
        await testManager.performTest(platform: "youtube") {
            Log.app.info("[YouTube] Test Post started - Using scheduled post from queue...")
            
            let connector = YouTubeConnector()
            guard await connector.isConfigured else {
                let msg = "YouTube not configured. Try disconnecting and reconnecting."
                return TestPostResult(success: false, message: msg, postURL: nil)
            }
            
            // Get the scheduled post for today
            guard let scheduledPost = await getScheduledPostForToday(),
                  let content = scheduledPost.content else {
                let msg = "No scheduled post available. Check Post Queue."
                return TestPostResult(success: false, message: msg, postURL: nil)
            }
            
            let title = content.prefix(60).replacingOccurrences(of: "\n", with: " ")
            Log.app.info("[YouTube] Using scheduled post: \(title)")
            
            let finalVideoURL: URL
            if let existingURL = await findExistingVideo(for: title) {
                finalVideoURL = existingURL
                Log.app.info("[YouTube] Using existing video: \(finalVideoURL.lastPathComponent)")
            } else {
                Log.app.info("[YouTube] Generating new video for: \(title)")
                let videoGen = VideoGenerator()
                let entry = WisdomEntry(
                    id: UUID(),
                    title: String(title),
                    content: content,
                    reference: nil,
                    link: scheduledPost.link ?? URL(string: "https://wisdombook.life")!,
                    pubDate: Date(),
                    category: .thought
                )
                
                do {
                    guard let generatedURL = try await videoGen.generateVideo(entry: entry) else {
                        let msg = "Video generation failed - no URL returned"
                        ErrorLog.shared.log(category: "YouTube", message: "Video generation failed", detail: msg)
                        return TestPostResult(success: false, message: msg, postURL: nil)
                    }
                    finalVideoURL = generatedURL
                    Log.app.info("[YouTube] Video generated successfully: \(finalVideoURL.lastPathComponent)")
                } catch let error as VideoGenerationError {
                    let errorDetail: String
                    switch error {
                    case .serverUnavailable:
                        errorDetail = "Social Effects server unavailable. Check that the server is running."
                    case .generationFailed(let message):
                        errorDetail = "Generation failed: \(message)"
                    case .unknown(let underlying):
                        errorDetail = "Unknown error: \(underlying.localizedDescription)"
                    }
                    ErrorLog.shared.log(category: "YouTube", message: "Video generation error", detail: errorDetail)
                    return TestPostResult(success: false, message: errorDetail, postURL: nil)
                }
            }
            
            let caption = "\(title)\n\n\(content)\n\n#Shorts #Wisdom #BookOfWisdom"
            Log.app.info("[YouTube] Uploading video: \(title.prefix(50))")
            let result = try await connector.postVideo(finalVideoURL, caption: caption)
            
            if result.success {
                Log.app.info("[YouTube] Posted scheduled content successfully!")
            } else {
                let detail = result.error?.localizedDescription ?? "Unknown error"
                ErrorLog.shared.log(category: "YouTube", message: "YouTube upload failed", detail: detail)
            }
            
            return TestPostResult(
                success: result.success,
                message: result.success ? "Posted scheduled content to YouTube! 🎬" : (result.error?.localizedDescription ?? "Unknown error"),
                postURL: result.postURL
            )
        }
    }
}
