//
//  TestPostManager.swift
//  SocialMarketer
//
//  Centralized test post management for all platforms.
//  Eliminates duplicate test post logic across PlatformSettingsView extensions.
//

import SwiftUI
import Combine

/// Result of a test post operation
struct TestPostResult {
    let success: Bool
    let message: String
    let postURL: URL?
}

/// Manages test posting across all platforms with unified state handling
@MainActor
class TestPostManager: ObservableObject, TestPostServiceProtocol {
    
    static let shared = TestPostManager()
    
    // MARK: - Published State
    
    @Published private(set) var isTesting = false
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var message = ""
    
    // Per-platform testing states
    @Published private(set) var testingPlatforms: Set<String> = []
    
    private init() {}
    
    // MARK: - State Management
    
    func isTesting(platform: String) -> Bool {
        testingPlatforms.contains(platform)
    }
    
    private func setTesting(_ testing: Bool, for platform: String) {
        if testing {
            testingPlatforms.insert(platform)
        } else {
            testingPlatforms.remove(platform)
        }
    }
    
    // MARK: - Test Post Methods
    
    /// Get the scheduled post for today from the queue
    private func getScheduledPost() async -> Post? {
        let context = PersistenceController.shared.viewContext
        return await context.perform {
            let pending = Post.fetchPending(in: context)
            let now = Date()
            
            // Find post scheduled for today (or earliest due post)
            return pending.first { post in
                guard let scheduled = post.scheduledDate else { return false }
                return scheduled <= now
            } ?? pending.min { post1, post2 in
                guard let date1 = post1.scheduledDate else { return false }
                guard let date2 = post2.scheduledDate else { return true }
                return date1 < date2
            }
        }
    }
    
    /// Generate content and image for test post from scheduled post
    private func prepareScheduledContent() async -> (content: String, image: NSImage?, link: URL, title: String)? {
        guard let scheduledPost = await getScheduledPost() else {
            ErrorLog.shared.log(category: "TestPost", message: "No scheduled post available", detail: "Queue is empty or no due posts")
            return nil
        }
        
        guard let content = scheduledPost.content else {
            ErrorLog.shared.log(category: "TestPost", message: "Scheduled post has no content", detail: nil)
            return nil
        }
        
        let link = scheduledPost.link ?? URL(string: AppConfiguration.URLs.wisdomBook)!
        let title = String(content.prefix(60)).replacingOccurrences(of: "\n", with: " ")
        
        // Generate graphic for the content
        let generator = QuoteGraphicGenerator()
        let entry = WisdomEntry(
            id: UUID(),
            title: title,
            content: content,
            reference: nil,
            link: link,
            pubDate: Date(),
            category: .thought
        )
        
        let image = generator.generate(from: entry)
        
        if image == nil {
            ErrorLog.shared.log(category: "TestPost", message: "Failed to generate graphic", detail: "Proceeding with text-only post")
        }
        
        return (content, image, link, title)
    }
    
    /// Test post to Twitter/X - uses scheduled post from queue
    func testTwitterPost() async {
        await performTest(platform: "twitter") {
            guard let prepared = await self.prepareScheduledContent() else {
                return TestPostResult(
                    success: false,
                    message: "No scheduled post available. Check Post Queue.",
                    postURL: nil
                )
            }
            
            let connector = TwitterConnector()
            _ = await connector.isConfigured
            
            let captionBuilder = CaptionBuilder()
            let entry = WisdomEntry(
                id: UUID(),
                title: prepared.title,
                content: prepared.content,
                reference: nil,
                link: prepared.link,
                pubDate: Date(),
                category: .thought
            )
            let caption = captionBuilder.buildHashtagCaption(from: entry)
            
            if let image = prepared.image {
                let result = try await connector.post(image: image, caption: caption, link: prepared.link)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Posted scheduled content to X! 🎉" : (result.error?.localizedDescription ?? "Failed to post"),
                    postURL: result.postURL
                )
            } else {
                let result = try await connector.postText(caption)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Posted scheduled content to X! 🎉" : (result.error?.localizedDescription ?? "Failed to post"),
                    postURL: result.postURL
                )
            }
        }
    }
    
    /// Test post to LinkedIn - uses scheduled post from queue
    func testLinkedInPost(oauthManager: OAuthManager) async {
        await performTest(platform: "linkedin") {
            guard let prepared = await self.prepareScheduledContent() else {
                return TestPostResult(
                    success: false,
                    message: "No scheduled post available. Check Post Queue.",
                    postURL: nil
                )
            }
            
            let connector = LinkedInConnector()
            let tokens = try oauthManager.getTokens(for: "linkedin")
            connector.setAccessToken(tokens.accessToken)
            
            guard let idToken = tokens.idToken else {
                return TestPostResult(
                    success: false,
                    message: "No id_token found. Please reconnect LinkedIn.",
                    postURL: nil
                )
            }
            connector.setIdToken(idToken)
            
            let captionBuilder = CaptionBuilder()
            let entry = WisdomEntry(
                id: UUID(),
                title: prepared.title,
                content: prepared.content,
                reference: nil,
                link: prepared.link,
                pubDate: Date(),
                category: .thought
            )
            let caption = captionBuilder.buildHashtagCaption(from: entry)
            
            if let image = prepared.image {
                let result = try await connector.post(image: image, caption: caption, link: prepared.link)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Posted scheduled content to LinkedIn! 🎉" : (result.error?.localizedDescription ?? "Failed to post"),
                    postURL: result.postURL
                )
            } else {
                let result = try await connector.postText(caption)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Posted scheduled content to LinkedIn! 🎉" : (result.error?.localizedDescription ?? "Failed to post"),
                    postURL: result.postURL
                )
            }
        }
    }
    
    /// Test post to Facebook - uses scheduled post from queue
    func testFacebookPost() async {
        await performTest(platform: "facebook") {
            guard let prepared = await self.prepareScheduledContent() else {
                return TestPostResult(
                    success: false,
                    message: "No scheduled post available. Check Post Queue.",
                    postURL: nil
                )
            }
            
            let connector = FacebookConnector()
            guard await connector.isConfigured else {
                return TestPostResult(
                    success: false,
                    message: "Facebook Page not configured. Try reconnecting.",
                    postURL: nil
                )
            }
            
            let captionBuilder = CaptionBuilder()
            let entry = WisdomEntry(
                id: UUID(),
                title: prepared.title,
                content: prepared.content,
                reference: nil,
                link: prepared.link,
                pubDate: Date(),
                category: .thought
            )
            let caption = captionBuilder.buildCaption(from: entry)
            
            if let image = prepared.image {
                let result = try await connector.post(image: image, caption: caption, link: prepared.link)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Posted scheduled content to Facebook! 🎉" : (result.error?.localizedDescription ?? "Failed to post"),
                    postURL: result.postURL
                )
            } else {
                let result = try await connector.postText(caption)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Posted scheduled content to Facebook! 🎉" : (result.error?.localizedDescription ?? "Failed to post"),
                    postURL: result.postURL
                )
            }
        }
    }
    
    /// Generic test post performer with error handling
    internal func performTest(
        platform: String,
        operation: () async throws -> TestPostResult
    ) async {
        setTesting(true, for: platform)
        defer { setTesting(false, for: platform) }
        
        do {
            let result = try await operation()
            await MainActor.run {
                if result.success {
                    var fullMessage = result.message
                    if let url = result.postURL {
                        fullMessage += "\n\(url.absoluteString)"
                    }
                    self.showSuccess(fullMessage)
                } else {
                    self.showError(result.message)
                }
            }
        } catch {
            await MainActor.run {
                self.showError("\(platform.capitalized) post failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Alert Helpers
    
    private func showSuccess(_ message: String) {
        self.message = message
        showingSuccess = true
    }
    
    func showError(_ message: String) {
        self.message = message
        showingError = true
    }
}

// MARK: - Test Post Button Component

/// Reusable test post button with loading state
struct TestPostButton: View {
    let platform: String
    let label: String
    @ObservedObject var manager: TestPostManager
    let action: () async -> Void
    
    var body: some View {
        Button(manager.isTesting(platform: platform) ? "Posting..." : label) {
            Task { await action() }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(manager.isTesting(platform: platform))
    }
}

// MARK: - View Alert Modifier

/// Unified alert modifier for error and success messages
struct TestPostAlertModifier: ViewModifier {
    @ObservedObject var manager: TestPostManager
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $manager.showingError) {
                Button("OK") {}
            } message: {
                Text(manager.message)
            }
            .alert("Success", isPresented: $manager.showingSuccess) {
                Button("OK") {}
            } message: {
                Text(manager.message)
            }
    }
}

extension View {
    /// Apply unified test post alerts
    func testPostAlerts(manager: TestPostManager) -> some View {
        modifier(TestPostAlertModifier(manager: manager))
    }
}
