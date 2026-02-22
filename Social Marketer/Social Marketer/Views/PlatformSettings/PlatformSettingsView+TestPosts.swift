//
//  PlatformSettingsView+TestPosts.swift
//  SocialMarketer
//
//  Test post methods for Twitter, LinkedIn, and Facebook
//  Refactored to use TestPostManager (state handled centrally)
//

import SwiftUI

extension PlatformSettingsView {
    
    // MARK: - Twitter Test Post
    
    @MainActor
    func testTwitterPost() async {
        await testManager.testTwitterPost()
    }
    
    // MARK: - LinkedIn Test Post
    
    @MainActor
    func testLinkedInPost() async {
        await testManager.testLinkedInPost(oauthManager: oauthManager)
    }
    
    // MARK: - Facebook Test Post
    
    @MainActor
    func testFacebookPost() async {
        await testManager.testFacebookPost()
    }
    
    // Note: Instagram, Pinterest, YouTube test methods remain in their respective files
    // They can be refactored similarly when needed
}
