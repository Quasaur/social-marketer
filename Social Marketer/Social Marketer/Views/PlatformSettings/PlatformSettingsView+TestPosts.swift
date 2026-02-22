//
//  PlatformSettingsView+TestPosts.swift
//  SocialMarketer
//
//  Test post methods for Twitter, LinkedIn, and Facebook
//

import SwiftUI

extension PlatformSettingsView {
    
    // MARK: - Twitter Test Post
    
    @MainActor
    func testTwitterPost() async {
        twitterTesting = true
        defer {
            Task { @MainActor in
                twitterTesting = false
            }
        }
        
        do {
            let connector = TwitterConnector()
            _ = await connector.isConfigured
            
            let caption = "📖 The Book of Wisdom — a curated collection of proverbs for the modern age.\n\n🔗 https://wisdombook.life\n\n#Wisdom #BookOfWisdom #Proverbs"
            
            if let imagePath = Bundle.main.path(forResource: "test_intro_graphic", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                let link = URL(string: "https://wisdombook.life")!
                let result = try await connector.post(image: image, caption: "", link: link)
                if result.success {
                    successMessage = "Image posted to X! 🎉\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            } else {
                let result = try await connector.postText(caption)
                if result.success {
                    successMessage = "Posted to X! 🎉\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            }
        } catch {
            errorMessage = "X post failed: \(error.localizedDescription)"
            showingError = true
        }
        
        twitterTesting = false
    }
    
    // MARK: - LinkedIn Test Post
    
    @MainActor
    func testLinkedInPost() async {
        linkedinTesting = true
        defer {
            Task { @MainActor in
                linkedinTesting = false
            }
        }
        
        let introText = ContentConstants.introText
        
        do {
            let connector = LinkedInConnector()
            let tokens = try oauthManager.getTokens(for: "linkedin")
            connector.setAccessToken(tokens.accessToken)
            if let idToken = tokens.idToken {
                connector.setIdToken(idToken)
            } else {
                errorMessage = "No id_token found. Please Disconnect and Connect LinkedIn again to get new tokens with openid scope."
                showingError = true
                return
            }
            let result = try await connector.postText(introText)
            if result.success {
                successMessage = "Posted to LinkedIn! 🎉\n\(result.postURL?.absoluteString ?? "")"
                showingSuccess = true
            }
        } catch {
            errorMessage = "LinkedIn post failed: \(error.localizedDescription)"
            showingError = true
        }
        
        linkedinTesting = false
    }
    
    // MARK: - Facebook Test Post
    
    @MainActor
    func testFacebookPost() async {
        facebookTesting = true
        defer {
            Task { @MainActor in
                facebookTesting = false
            }
        }
        
        let introText = """
        Since the creation of Twitter in 2006 I have been posting the Wisdom that The Spirit of Christ has graciously given to me.

        In 2015 I published The Book of Tweets: Proverbs for the Modern Age on Amazon Kindle. In it I placed well over 600 proverbs, maxims and adages.

        Since that time I have posted another 300 adages on 19 social media platforms in an effort to communicate with the world the critical importance of Biblical Wisdom to our mental health, fortune and survival.

        Now, in the latter days of my earthly journey, I am consolidating all of my work in a single Neo4j AURADB graph database which can be enjoyed by everyone free-of-charge through my new website The Book of Wisdom:

        https://www.wisdombook.life
        """
        
        do {
            let connector = FacebookConnector()
            guard await connector.isConfigured else {
                errorMessage = "Facebook Page not configured. Try disconnecting and reconnecting Facebook."
                showingError = true
                return
            }
            
            if let imagePath = Bundle.main.path(forResource: "test_intro_graphic", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                let link = URL(string: "https://www.wisdombook.life")!
                let result = try await connector.post(image: image, caption: introText, link: link)
                if result.success {
                    successMessage = "Intro posted to Facebook with graphic! 🎉\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            } else {
                let result = try await connector.postText(introText)
                if result.success {
                    successMessage = "Intro posted to Facebook! 🎉\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            }
        } catch {
            errorMessage = "Facebook post failed: \(error.localizedDescription)"
            showingError = true
        }
        
        facebookTesting = false
    }
}
