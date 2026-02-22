//
//  PlatformSettingsView+TestPostsPinterestYouTube.swift
//  SocialMarketer
//
//  Pinterest and YouTube test post methods for PlatformSettingsView
//

import SwiftUI

extension PlatformSettingsView {
    
    // MARK: - Pinterest Test Post
    
    @MainActor
    func testPinterestPost() async {
        pinterestTesting = true
        defer {
            Task { @MainActor in
                pinterestTesting = false
            }
        }
        do {
            let connector = PinterestConnector()
            if !(await connector.isConfigured) {
                if let _ = try? OAuthManager.shared.getTokens(for: "pinterest") {
                    errorMessage = "Pinterest board not configured. Please Disconnect and Connect Pinterest again to auto-discover your boards."
                    showingError = true
                    return
                }
            }
            guard await connector.isConfigured else {
                errorMessage = "Pinterest not configured. Try disconnecting and reconnecting."
                showingError = true
                return
            }
            let caption = """
            Since the creation of Twitter in 2006 I have been posting the Wisdom that The Spirit of Christ has graciously given to me.
            In 2015 I published The Book of Tweets: Proverbs for the Modern Age on Amazon Kindle. In it I placed well over 600 proverbs, maxims and adages.
            Since that time I have posted another 300 adages on 19 social media platforms in an effort to communicate with the world the critical importance of Biblical Wisdom to our mental health, fortune and survival.
            Now, in the latter days of my earthly journey, I am consolidating all of my work in a single Neo4j AURADB graph database which can be enjoyed by everyone free-of-charge through my new website The Book of Wisdom:
            https://www.wisdombook.life
            """
            if let imagePath = Bundle.main.path(forResource: "test_intro_graphic", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                let link = URL(string: "https://www.wisdombook.life")!
                let result = try await connector.post(image: image, caption: caption, link: link)
                if result.success {
                    successMessage = "Pinned to Pinterest! 📌\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                } else {
                    errorMessage = result.error?.localizedDescription ?? "Pinterest post failed"
                    showingError = true
                }
            } else {
                errorMessage = "Could not load intro graphic for Pinterest pin."
                showingError = true
            }
        } catch {
            errorMessage = "Pinterest pin failed: \(error.localizedDescription)"
            showingError = true
        }
        pinterestTesting = false
    }
    
    // MARK: - YouTube Test Post
    
    @MainActor
    func testYouTubePost() async {
        youtubeTesting = true
        defer {
            Task { @MainActor in
                youtubeTesting = false
            }
        }
        ErrorLog.shared.log(category: "YouTube", message: "Test Post started", detail: "Checking for queued content or RSS feed...")
        do {
            let connector = YouTubeConnector()
            guard await connector.isConfigured else {
                let msg = "YouTube not configured. Try disconnecting and reconnecting."
                ErrorLog.shared.log(category: "YouTube", message: "Test Post failed", detail: msg)
                errorMessage = msg
                showingError = true
                return
            }
            let (title, content, videoURL): (String, String, URL?)
            if let queuedPost = await getFirstPendingPost() {
                title = queuedPost.content?.prefix(60).replacingOccurrences(of: "\n", with: " ") ?? "Wisdom"
                content = queuedPost.content ?? ""
                ErrorLog.shared.log(category: "YouTube", message: "Using queued post: \(title)", detail: "Found pending post in Queue")
                videoURL = await findExistingVideo(for: title)
            } else {
                let rssParser = RSSParser()
                guard let entry = try await rssParser.fetchDaily() else {
                    let msg = "No posts in queue and RSS feed unavailable."
                    ErrorLog.shared.log(category: "YouTube", message: "Test Post failed", detail: msg)
                    errorMessage = msg
                    showingError = true
                    return
                }
                title = entry.title
                content = entry.content
                ErrorLog.shared.log(category: "YouTube", message: "Using RSS feed: \(title)", detail: "No queued posts found, fetched from RSS")
                videoURL = nil
            }
            let finalVideoURL: URL
            if let existingURL = videoURL {
                finalVideoURL = existingURL
                ErrorLog.shared.log(category: "YouTube", message: "Using existing video", detail: "Found: \(finalVideoURL.lastPathComponent)")
            } else {
                ErrorLog.shared.log(category: "YouTube", message: "Generating new video", detail: "No existing video found for: \(title)")
                successMessage = "Generating video... This may take a moment."
                showingSuccess = true
                let videoGen = VideoGenerator()
                let entry = WisdomEntry(id: UUID(), title: title, content: content, reference: nil, link: URL(string: "https://wisdombook.life")!, pubDate: Date(), category: .thought)
                let manager = SocialEffectsProcessManager.shared
                let serverRunning = await manager.serverIsRunning
                ErrorLog.shared.log(category: "YouTube", message: "Social Effects status check", detail: "Server running: \(serverRunning)")
                do {
                    ErrorLog.shared.log(category: "YouTube", message: "Starting video generation", detail: "Title: \(title)")
                    guard let generatedURL = try await videoGen.generateVideo(entry: entry) else {
                        let msg = "Video generation failed - no URL returned"
                        ErrorLog.shared.log(category: "YouTube", message: "Video generation failed", detail: msg)
                        errorMessage = msg
                        showingError = true
                        return
                    }
                    finalVideoURL = generatedURL
                    ErrorLog.shared.log(category: "YouTube", message: "Video generated successfully", detail: "Saved to: \(finalVideoURL.lastPathComponent)")
                } catch let error as VideoGenerationError {
                    let errorDetail: String
                    switch error {
                    case .serverUnavailable:
                        errorDetail = "Social Effects server unavailable. Check that the server is running on port 5390."
                    case .generationFailed(let message):
                        errorDetail = "Generation failed: \(message)"
                    case .unknown(let underlying):
                        errorDetail = "Unknown error: \(underlying.localizedDescription)"
                    }
                    ErrorLog.shared.log(category: "YouTube", message: "Video generation error: \(error)", detail: errorDetail)
                    errorMessage = errorDetail
                    showingError = true
                    return
                } catch {
                    ErrorLog.shared.log(category: "YouTube", message: "Video generation failed", detail: error.localizedDescription)
                    throw error
                }
            }
            let caption = "\(title)\n\n\(content)\n\n#Shorts #Wisdom #BookOfWisdom"
            ErrorLog.shared.log(category: "YouTube", message: "Uploading to YouTube", detail: "Title: \(title.prefix(50))")
            let result = try await connector.postVideo(finalVideoURL, caption: caption)
            if result.success {
                if let queuedPost = await getFirstPendingPost() {
                    await markPostAsPosted(queuedPost, result: result)
                }
                let msg = "Posted to YouTube! 🎬"
                let detail = "URL: \(result.postURL?.absoluteString ?? "No URL")\nPost ID: \(result.postID ?? "No ID")"
                ErrorLog.shared.log(category: "YouTube", message: msg, detail: detail)
                successMessage = "✅ \(msg)\n\(result.postURL?.absoluteString ?? "")"
                showingSuccess = true
            } else {
                let detail = result.error?.localizedDescription ?? "Unknown error"
                ErrorLog.shared.log(category: "YouTube", message: "YouTube upload failed", detail: detail)
                errorMessage = detail
                showingError = true
            }
        } catch {
            let detail = "YouTube post failed: \(error.localizedDescription)"
            ErrorLog.shared.log(category: "YouTube", message: "Test Post failed", detail: detail)
            errorMessage = detail
            showingError = true
        }
        youtubeTesting = false
    }
}
