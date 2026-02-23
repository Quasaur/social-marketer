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
            ErrorLog.shared.log(
                category: "Instagram",
                message: "Test Post started",
                detail: "Using scheduled post from queue..."
            )
            
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
            
            ErrorLog.shared.log(
                category: "Instagram",
                message: "Using scheduled post: \(title)",
                detail: "Posting to Instagram..."
            )
            
            let caption = "\(content)\n\n📖 Read more at wisdombook.life"
            let result: PostResult
            
            if instagramPlatform.prefersVideo {
                ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Platform prefers video - attempting Reel post")
                
                if let existingVideoURL = await findExistingVideo(for: String(title)) {
                    ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Using existing video: \(existingVideoURL.lastPathComponent)")
                    result = try await connector.postVideo(existingVideoURL, caption: caption)
                } else {
                    ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Generating new video for: \(title)")
                    
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
                    
                    guard let videoURL = try await videoGen.generateVideo(entry: entry) else {
                        // Video generation failed - log error and fail (don't fallback to image)
                        let errorMsg = "Video generation failed for Instagram Reel. Platform is set to video preference."
                        ErrorLog.shared.log(category: "Instagram", message: "Test Post failed", detail: errorMsg)
                        return TestPostResult(
                            success: false,
                            message: errorMsg,
                            postURL: nil
                        )
                    }
                    result = try await connector.postVideo(videoURL, caption: caption)
                }
            } else {
                ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Platform prefers image - generating graphic")
                
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
            
            return TestPostResult(
                success: result.success,
                message: result.success ? "Posted scheduled content to Instagram! 🎉" : (result.error?.localizedDescription ?? "Unknown error"),
                postURL: result.postURL
            )
        }
    }
}
