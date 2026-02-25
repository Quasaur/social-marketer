//
//  PlatformSettingsView+TestPostsInstagram.swift
//  SocialMarketer
//
//  Instagram test post method for PlatformSettingsView
//  Uses the scheduled post for the day from the queue
//

import SwiftUI

extension PlatformSettingsView {
    
    @MainActor
    func testInstagramPost() async {
        await testManager.performTest(platform: "instagram") {
            Log.app.info("[Instagram] Test Post started - Using scheduled post from queue...")
            
            let connector = InstagramConnector()
            guard await connector.isConfigured else {
                return TestPostResult(
                    success: false,
                    message: "Instagram not configured. Try disconnecting and reconnecting.",
                    postURL: nil
                )
            }
            
            let context = PersistenceController.shared.viewContext
            guard let instagramPlatform = Platform.find(name: "Instagram", in: context) else {
                return TestPostResult(
                    success: false,
                    message: "Instagram platform not found in database.",
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
            
            let caption = content  // InstagramConnector will add the "Read more" text
            let result: PostResult
            
            if instagramPlatform.prefersVideo {
                Log.app.info("[Instagram] Test Post - Platform prefers video, attempting Reel post")
                
                // Ensure Social Effects server is running before attempting video generation
                Log.app.info("[Instagram] Ensuring Social Effects server is running...")
                let serverReady = await SocialEffectsService.shared.ensureServerRunning()
                guard serverReady else {
                    let errorMsg = "Social Effects video server is not available. Please ensure it's installed at ~/Developer/social-effects/"
                    ErrorLog.shared.log(category: "Instagram", message: "Video server unavailable", detail: errorMsg)
                    return TestPostResult(
                        success: false,
                        message: errorMsg,
                        postURL: nil
                    )
                }
                Log.app.info("[Instagram] Social Effects server ready")
                
                if let existingVideoURL = await findExistingVideo(for: String(title)) {
                    Log.app.info("[Instagram] Test Post - Using existing video: \(existingVideoURL.lastPathComponent)")
                    result = try await connector.postVideo(existingVideoURL, caption: caption)
                } else {
                    Log.app.info("[Instagram] Test Post - Generating new video for: \(title)")
                    
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
                            ErrorLog.shared.log(category: "Instagram", message: "Video generation failed", detail: errorMsg)
                            return TestPostResult(
                                success: false,
                                message: errorMsg,
                                postURL: nil
                            )
                        }
                        Log.app.info("[Instagram] Video generated: \(videoURL.lastPathComponent)")
                        result = try await connector.postVideo(videoURL, caption: caption)
                    } catch let error as VideoGenerationError {
                        let errorMsg = error.localizedDescription
                        ErrorLog.shared.log(category: "Instagram", message: "Video generation error", detail: errorMsg)
                        return TestPostResult(
                            success: false,
                            message: "Video generation failed: \(errorMsg)",
                            postURL: nil
                        )
                    }
                }
            } else {
                Log.app.info("[Instagram] Test Post - Platform prefers image, generating graphic")
                
                let generator = QuoteGraphicGenerator()
                let imageEntry = WisdomEntry(
                    id: UUID(),
                    title: String(title),
                    content: content,
                    reference: nil,
                    link: link,
                    pubDate: Date(),
                    category: .thought
                )
                guard let image = generator.generate(from: imageEntry) else {
                    return TestPostResult(
                        success: false,
                        message: "Could not generate image for Instagram post.",
                        postURL: nil
                    )
                }
                
                result = try await connector.post(image: image, caption: caption, link: link)
            }
            
            if result.success {
                return TestPostResult(
                    success: true,
                    message: "Posted scheduled content to Instagram! 🎉",
                    postURL: result.postURL
                )
            } else {
                let errorMsg = result.error?.localizedDescription ?? "Unknown error"
                ErrorLog.shared.log(category: "Instagram", message: "Test post failed", detail: errorMsg)
                return TestPostResult(
                    success: false,
                    message: "Failed to post: \(errorMsg)",
                    postURL: nil
                )
            }
        }
    }
}
