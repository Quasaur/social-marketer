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
        instagramTesting = true
        defer {
            Task { @MainActor in
                instagramTesting = false
            }
        }
        
        ErrorLog.shared.log(
            category: "Instagram",
            message: "Test Post started",
            detail: "Checking for queued content or RSS feed..."
        )
        
        do {
            let connector = InstagramConnector()
            guard await connector.isConfigured else {
                errorMessage = "Instagram not configured. Try disconnecting and reconnecting."
                showingError = true
                return
            }
            
            let context = PersistenceController.shared.viewContext
            guard let instagramPlatform = Platform.find(name: "Instagram", in: context) else {
                errorMessage = "Instagram platform not found in database."
                showingError = true
                return
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
            } else {
                let rssParser = RSSParser()
                guard let entry = try await rssParser.fetchDaily() else {
                    errorMessage = "No posts in queue and RSS feed unavailable."
                    ErrorLog.shared.log(category: "Instagram", message: "Test Post failed", detail: "No content available")
                    showingError = true
                    return
                }
                title = entry.title
                content = entry.content
                link = entry.link
                ErrorLog.shared.log(
                    category: "Instagram",
                    message: "Using RSS feed: \(title)",
                    detail: "No queued posts found, fetched from RSS"
                )
            }
            
            let caption = "\(content)\n\n📖 Read more at wisdombook.life"
            let result: PostResult
            
            if instagramPlatform.prefersVideo {
                ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Platform prefers video - attempting Reel post")
                
                if let existingVideoURL = await findExistingVideo(for: title) {
                    ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Using existing video: \(existingVideoURL.lastPathComponent)")
                    result = try await connector.postVideo(existingVideoURL, caption: caption)
                    
                    if result.success {
                        successMessage = "Posted EXISTING VIDEO to Instagram! 🎉\n\(result.postURL?.absoluteString ?? "")"
                        showingSuccess = true
                    } else {
                        errorMessage = result.error?.localizedDescription ?? "Unknown error"
                        showingError = true
                    }
                    return
                }
                
                ErrorLog.shared.log(category: "Instagram", message: "Test Post", detail: "Generating new video for: \(title)")
                successMessage = "Generating video... This may take 2-3 minutes."
                showingSuccess = true
                
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
                        errorMessage = "Could not generate image for Instagram post."
                        showingError = true
                        return
                    }
                    
                    result = try await connector.post(image: image, caption: caption, link: link)
                    
                    if result.success {
                        successMessage = "Posted IMAGE to Instagram (video generation failed). 🎉\n\(result.postURL?.absoluteString ?? "")"
                        showingSuccess = true
                    } else {
                        errorMessage = result.error?.localizedDescription ?? "Unknown error"
                        showingError = true
                    }
                    return
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
                    errorMessage = "Could not generate image for Instagram post."
                    showingError = true
                    return
                }
                
                result = try await connector.post(image: image, caption: caption, link: link)
            }
            
            if result.success {
                successMessage = "Posted to Instagram! 🎉\n\(result.postURL?.absoluteString ?? "")"
                showingSuccess = true
            } else {
                errorMessage = result.error?.localizedDescription ?? "Unknown error"
                showingError = true
            }
            
        } catch let videoError as VideoGenerationError {
            switch videoError {
            case .serverUnavailable:
                errorMessage = "Video generation server unavailable. Check that Social Effects is installed."
                ErrorLog.shared.log(category: "Instagram", message: "Test Post failed", detail: "Server unavailable")
            case .generationFailed(let message):
                errorMessage = "Video generation failed: \(message)"
                ErrorLog.shared.log(category: "Instagram", message: "Test Post failed", detail: message)
            case .unknown(let underlying):
                errorMessage = "Video generation error: \(underlying.localizedDescription)"
                ErrorLog.shared.log(category: "Instagram", message: "Test Post failed", detail: "\(underlying)")
            }
            showingError = true
        } catch {
            errorMessage = "Instagram post failed: \(error.localizedDescription)"
            showingError = true
            ErrorLog.shared.log(category: "Instagram", message: "Test Post failed", detail: "\(error)")
        }
        
        instagramTesting = false
    }
}
