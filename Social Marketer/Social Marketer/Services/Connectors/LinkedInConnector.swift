//
//  LinkedInConnector.swift
//  SocialMarketer
//
//  Created by Automation on 2026-02-16.
//

import Foundation
import AppKit

// MARK: - LinkedIn Connector

/// Credentials for LinkedIn person identity, stored in Keychain
struct LinkedInProfileCredentials: Codable {
    let personURN: String
}

final class LinkedInConnector: PlatformConnector {
    let platformName = "LinkedIn"
    private let logger = Log.linkedin
    private var accessToken: String?
    private var personURN: String?
    
    var isConfigured: Bool {
        get async {
            // Load person URN from Keychain
            if personURN == nil {
                if let cached = try? KeychainService.shared.retrieve(LinkedInProfileCredentials.self, for: "linkedin_profile") {
                    personURN = cached.personURN
                }
            }
            
            do {
                let tokens = try OAuthManager.shared.getTokens(for: "linkedin")
                accessToken = tokens.accessToken
                
                // Migration: extract personURN from stored idToken if not yet persisted
                if personURN == nil, let idToken = tokens.idToken {
                    setIdToken(idToken)
                    if let urn = personURN {
                        let profileCreds = LinkedInProfileCredentials(personURN: urn)
                        try? KeychainService.shared.save(profileCreds, for: "linkedin_profile")
                        print("[LinkedIn] Migrated personURN from idToken: \(urn)")
                    }
                }
                
                // Fallback: fetch personURN from /v2/userinfo API
                if personURN == nil, let token = accessToken {
                    if let fetchedURN = try? await fetchPersonURN(token: token) {
                        personURN = fetchedURN
                        let profileCreds = LinkedInProfileCredentials(personURN: fetchedURN)
                        try? KeychainService.shared.save(profileCreds, for: "linkedin_profile")
                        print("[LinkedIn] Fetched personURN from API: \(fetchedURN)")
                    }
                }
                
                return accessToken != nil && personURN != nil
            } catch {
                return false
            }
        }
    }
    
    func configure(personURN: String) {
        self.personURN = personURN
    }
    
    func setAccessToken(_ token: String) {
        self.accessToken = token
    }
    
    func setIdToken(_ idToken: String) {
        // Decode JWT to extract sub claim (person ID)
        if let personID = JWTUtils.extractSubject(idToken) {
            self.personURN = "urn:li:person:\(personID)"
            logger.info("Person URN from id_token: \(self.personURN ?? "nil")")
        }
    }
    
    /// Fetch personURN from LinkedIn /v2/userinfo endpoint (OpenID Connect)
    private func fetchPersonURN(token: String) async throws -> String {
        let url = URL(string: "https://api.linkedin.com/v2/userinfo")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[LinkedIn] userinfo fetch failed: \(errorBody)")
            throw PlatformError.postFailed("LinkedIn userinfo failed: \(errorBody)")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else {
            throw PlatformError.postFailed("Could not parse LinkedIn userinfo response")
        }
        
        return "urn:li:person:\(sub)"
    }
    
    func authenticate() async throws {
        let config = try OAuthManager.shared.getConfig(for: "linkedin")
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "linkedin",
            config: config
        )
        try OAuthManager.shared.saveTokens(tokens, for: "linkedin")
        accessToken = tokens.accessToken
        
        // Extract person URN from id_token JWT
        if let idToken = tokens.idToken {
            setIdToken(idToken)
        }
        
        // Persist personURN to Keychain for launchd scheduler access
        if let urn = personURN {
            let profileCreds = LinkedInProfileCredentials(personURN: urn)
            try KeychainService.shared.save(profileCreds, for: "linkedin_profile")
            logger.info("LinkedIn profile persisted: \(urn)")
        }
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let token = accessToken, let urn = personURN else {
            print("[LinkedIn] post() guard failed: accessToken=\(accessToken != nil), personURN=\(personURN ?? "nil")")
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.pngData() else {
            print("[LinkedIn] Failed to convert image to PNG")
            throw PlatformError.postFailed("Failed to convert image to PNG")
        }
        
        print("[LinkedIn] Starting image post (personURN=\(urn), imageSize=\(imageData.count))")
        
        // Step 1: Register image upload
        let (uploadURL, imageURN) = try await registerImageUpload(personURN: urn, token: token)
        print("[LinkedIn] Image registered: \(imageURN)")
        
        // Step 2: Upload the image binary
        try await uploadImage(data: imageData, to: uploadURL, token: token)
        print("[LinkedIn] Image uploaded successfully")
        
        // Step 3: Create UGC post with image (caption is pre-built by caller)
        print("[LinkedIn] Creating post with imageURN=\(imageURN)")
        let postID = try await createPost(text: caption, imageURN: imageURN, personURN: urn, token: token)
        
        logger.info("LinkedIn post created: \(postID)")
        
        return PostResult(
            success: true,
            postID: postID,
            postURL: URL(string: "https://www.linkedin.com/feed/update/\(postID)"),
            error: nil
        )
    }
    
    private func registerImageUpload(personURN: String, token: String) async throws -> (uploadURL: URL, imageURN: String) {
        let url = URL(string: "https://api.linkedin.com/v2/images?action=initializeUpload")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2.0.0", forHTTPHeaderField: "LinkedIn-Version")
        
        let payload: [String: Any] = [
            "initializeUploadRequest": [
                "owner": personURN
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[LinkedIn] Image registration failed: \(errorBody)")
            throw PlatformError.postFailed("Image registration failed: \(errorBody)")
        }
        
        struct RegisterResponse: Decodable {
            struct Value: Decodable {
                let uploadUrl: String
                let image: String
            }
            let value: Value
        }
        
        let registerResponse = try JSONDecoder().decode(RegisterResponse.self, from: data)
        guard let uploadURL = URL(string: registerResponse.value.uploadUrl) else {
            throw PlatformError.postFailed("Invalid upload URL")
        }
        
        return (uploadURL, registerResponse.value.image)
    }
    
    private func uploadImage(data: Data, to url: URL, token: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            print("[LinkedIn] Image upload failed (\(statusCode)): \(errorBody)")
            throw PlatformError.postFailed("Image upload failed (\(statusCode))")
        }
    }
    
    private func createPost(text: String, imageURN: String, personURN: String, token: String) async throws -> String {
        let url = URL(string: "https://api.linkedin.com/v2/posts")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2.0.0", forHTTPHeaderField: "LinkedIn-Version")
        
        let payload: [String: Any] = [
            "author": personURN,
            "commentary": text,
            "visibility": "PUBLIC",
            "distribution": [
                "feedDistribution": "MAIN_FEED",
                "targetEntities": [],
                "thirdPartyDistributionChannels": []
            ],
            "content": [
                "media": [
                    "id": imageURN
                ]
            ],
            "lifecycleState": "PUBLISHED",
            "isReshareDisabledByAuthor": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[LinkedIn] Post creation failed (\(statusCode)): \(errorBody)")
            throw PlatformError.postFailed("Post creation failed (\(statusCode)): \(errorBody)")
        }
        
        // Get post ID from x-restli-id header
        if let postID = httpResponse.value(forHTTPHeaderField: "x-restli-id") {
            return postID
        }
        
        // Some LinkedIn API versions don't return this header, but the post was still created
        print("[LinkedIn] Post created (201) but no x-restli-id header")
        return "created"
    }
    
    /// Post text-only content (no image) to LinkedIn
    func postText(_ text: String) async throws -> PostResult {
        guard let token = accessToken, let urn = personURN else {
            throw PlatformError.notConfigured
        }
        
        let postID = try await createTextPost(text: text, personURN: urn, token: token)
        
        logger.info("LinkedIn text post created: \(postID)")
        
        return PostResult(
            success: true,
            postID: postID,
            postURL: URL(string: "https://www.linkedin.com/feed/update/\(postID)"),
            error: nil
        )
    }
    
    private func createTextPost(text: String, personURN: String, token: String) async throws -> String {
        let url = URL(string: "https://api.linkedin.com/v2/posts")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2.0.0", forHTTPHeaderField: "LinkedIn-Version")
        
        let payload: [String: Any] = [
            "author": personURN,
            "commentary": text,
            "visibility": "PUBLIC",
            "distribution": [
                "feedDistribution": "MAIN_FEED",
                "targetEntities": [] as [[String: Any]],
                "thirdPartyDistributionChannels": [] as [[String: Any]]
            ],
            "lifecycleState": "PUBLISHED",
            "isReshareDisabledByAuthor": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlatformError.postFailed("No HTTP response")
        }
        
        guard httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Post creation failed (\(httpResponse.statusCode)): \(errorBody)")
        }
        
        // Post was created successfully (201)
        if let postID = httpResponse.value(forHTTPHeaderField: "x-restli-id") {
            return postID
        }
        
        // Some LinkedIn API versions don't return the header, but post was still created
        logger.info("Post created (201) but no x-restli-id header returned")
        return "created"
    }
}
