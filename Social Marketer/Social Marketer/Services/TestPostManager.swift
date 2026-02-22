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
    
    /// Test post to Twitter/X
    func testTwitterPost() async {
        await performTest(platform: "twitter") {
            let connector = TwitterConnector()
            _ = await connector.isConfigured
            
            let caption = ContentConstants.shortDescription
            
            if let imagePath = Bundle.main.path(forResource: "test_intro_graphic", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                let link = URL(string: AppConfiguration.URLs.wisdomBook)!
                let result = try await connector.post(image: image, caption: "", link: link)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Image posted to X! 🎉" : "Failed to post image",
                    postURL: result.postURL
                )
            } else {
                let result = try await connector.postText(caption)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Posted to X! 🎉" : "Failed to post",
                    postURL: result.postURL
                )
            }
        }
    }
    
    /// Test post to LinkedIn
    func testLinkedInPost(oauthManager: OAuthManager) async {
        await performTest(platform: "linkedin") {
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
            
            let result = try await connector.postText(ContentConstants.introText)
            return TestPostResult(
                success: result.success,
                message: result.success ? "Posted to LinkedIn! 🎉" : "Failed to post",
                postURL: result.postURL
            )
        }
    }
    
    /// Test post to Facebook
    func testFacebookPost() async {
        await performTest(platform: "facebook") {
            let connector = FacebookConnector()
            guard await connector.isConfigured else {
                return TestPostResult(
                    success: false,
                    message: "Facebook Page not configured. Try reconnecting.",
                    postURL: nil
                )
            }
            
            let introText = ContentConstants.introText
            let link = URL(string: AppConfiguration.URLs.wisdomBook)!
            
            if let imagePath = Bundle.main.path(forResource: "test_intro_graphic", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                let result = try await connector.post(image: image, caption: introText, link: link)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Intro posted to Facebook with graphic! 🎉" : "Failed to post",
                    postURL: result.postURL
                )
            } else {
                let result = try await connector.postText(introText)
                return TestPostResult(
                    success: result.success,
                    message: result.success ? "Intro posted to Facebook! 🎉" : "Failed to post",
                    postURL: result.postURL
                )
            }
        }
    }
    
    /// Generic test post performer with error handling
    private func performTest(
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
