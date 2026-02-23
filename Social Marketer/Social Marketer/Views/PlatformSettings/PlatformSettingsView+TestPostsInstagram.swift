//
//  PlatformSettingsView+TestPostsInstagram.swift
//  SocialMarketer
//
//  Instagram test post method for PlatformSettingsView
//

import SwiftUI

extension PlatformSettingsView {
    
    @MainActor
    func testInstagramPost() async {
        await testManager.performTest(platform: "instagram") {
            ErrorLog.shared.log(
                category: "Instagram",
                message: "Test Post started",
                detail: "Checking for queued content or RSS feed..."
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
            
            let (title, content, link): (String, String, URL)
            
            if let queuedPost = await getFirstPendingPost() {
                title = queuedPost.content?.prefix(60).replacingOccurrences(of: "\n", with: " ") ?? "Wisdom"
                content = queuedPost.content ?? ""
                link = queuedPost.link ?? URL(string: "https://wisdombook.life")!
                ErrorLog.shared.log(
                    category: "Instagram",
                    message: "Using queued post: \(title)",
                    detail: "Found pending post in Queue"
                )
            } else if let cachedEntry = await ContentService.shared.getNextEntryForPosting() {
                // Fall back to Content Library cache
                title = cachedEntry.title ?? "Wisdom"
                content = cachedEntry.content ?? ""
                link = cachedEntry.link ?? URL(string: "https://wisdombook.life")!
                ErrorLog.shared.log(
                    category: "Instagram",
                    message: "Using Content Library: \(title)",
                    detail: "No queued posts, using cached entry"
                )
            } else {
                // Last resort: try RSS directly
                let rssParser = RSSParser()
                guard let entry = try await rssParser.fetchDaily() else {
                    ErrorLog.shared.log(category: "Instagram", message: "Test Post failed", detail: "No content available")
                    return TestPostResult(
                        success: false,
                        message: "No posts in queue, Content Library empty, and RSS feed unavailable.",
                        postURL: nil
                    )
                }
                title = entry.title
                content = entry.content
                link = entry.link
                ErrorLog.shared.log(
                    category: "Instagram",
                    message: "Using RSS feed: \(title)",
                    detail: "No cached content, fetched from RSS"
                )
            }
            
            let caption = "\(content)\n\n📖 Read more at wisdombook.life"
            let result: PostResult
            
            if instagramPlatform.prefersVideo {
                ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Platform prefers video - attempting Reel post")
                
                if let existingVideoURL = await findExistingVideo(for: title) {
                    ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Using existing video: \(existingVideoURL.lastPathComponent)")
                    result = try await connector.postVideo(existingVideoURL, caption: caption)
                    return TestPostResult(
                        success: result.success,
                        message: result.success ? "Posted EXISTING VIDEO to Instagram! 🎉" : (result.error?.localizedDescription ?? "Unknown error"),
                        postURL: result.postURL
                    )
                }
                
                ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Generating new video for: \(title)")
                
                let videoGen = VideoGenerator()
                let entry = WisdomEntry(
                    id: UUID(),
                    title: title,
                    content: content,
                    reference: nil,
                    link: link,
                    pubDate: Date(),
                    category: .thought
                )
                
                guard let videoURL = try await videoGen.generateVideo(entry: entry) else {
                    ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Video generation returned nil - falling back to image")
                    
                    let generator = QuoteGraphicGenerator()
                    let fallbackEntry = WisdomEntry(
                        id: UUID(),
                        title: title,
                        content: content,
                        reference: nil,
                        link: link,
                        pubDate: Date(),
                        category: .thought
                    )
                    guard let image = generator.generate(from: fallbackEntry) else {
                        return TestPostResult(
                            success: false,
                            message: "Could not generate image for Instagram post.",
                            postURL: nil
                        )
                    }
                    
                    result = try await connector.post(image: image, caption: caption, link: link)
                    return TestPostResult(
                        success: result.success,
                        message: result.success ? "Posted IMAGE to Instagram (video generation failed). 🎉" : (result.error?.localizedDescription ?? "Unknown error"),
                        postURL: result.postURL
                    )
                }
                
                result = try await connector.postVideo(videoURL, caption: caption)
            } else {
                ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Platform prefers image - generating graphic")
                
                let generator = QuoteGraphicGenerator()
                let imageEntry = WisdomEntry(
                    id: UUID(),
                    title: title,
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
                message: result.success ? "Posted to Instagram! 🎉" : (result.error?.localizedDescription ?? "Unknown error"),
                postURL: result.postURL
            )
        }
    }
}
