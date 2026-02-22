//
//  TwitterConnector.swift
//  SocialMarketer
//
//  Refactored to use MultipartFormBuilder for media uploads.
//

import Foundation
import AppKit

// MARK: - Twitter/X Connector

final class TwitterConnector: PlatformConnector {
    
    let platformName = "X (Twitter)"
    private let logger = Log.twitter
    private var signer: OAuth1Signer?
    
    var isConfigured: Bool {
        get async {
            do {
                let creds = try OAuthManager.shared.getTwitterOAuth1Credentials()
                signer = OAuth1Signer(
                    consumerKey: creds.consumerKey,
                    consumerSecret: creds.consumerSecret,
                    accessToken: creds.accessToken,
                    accessTokenSecret: creds.accessTokenSecret
                )
                return true
            } catch {
                return false
            }
        }
    }
    
    func authenticate() async throws {
        // OAuth 1.0a uses pre-generated tokens from the X Developer Portal
        // No browser flow needed — just verify credentials are stored
        if signer == nil {
            let creds = try OAuthManager.shared.getTwitterOAuth1Credentials()
            signer = OAuth1Signer(
                consumerKey: creds.consumerKey,
                consumerSecret: creds.consumerSecret,
                accessToken: creds.accessToken,
                accessTokenSecret: creds.accessTokenSecret
            )
        }
    }
    
    /// Post a text-only tweet (useful for testing the auth pipeline)
    func postText(_ text: String) async throws -> PostResult {
        guard let signer = signer else {
            throw PlatformError.notConfigured
        }
        
        let result = try await createTweet(text: text, mediaID: nil, signer: signer)
        
        logger.info("Text tweet posted successfully: \(result.id)")
        
        let postURL = URL(string: "https://x.com/i/status/\(result.id)")
        return PostResult(success: true, postID: result.id, postURL: postURL, error: nil)
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let signer = signer else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        // Step 1: Upload media using v1.1 media upload (OAuth 1.0a signed)
        let mediaID = try await uploadMedia(imageData: imageData, signer: signer)
        
        // Step 2: Create tweet with media (caption is pre-built by caller)
        let tweetResult = try await createTweet(text: caption, mediaID: mediaID, signer: signer)
        
        logger.info("Tweet posted successfully: \(tweetResult.id)")
        
        let postURL = URL(string: "https://x.com/i/status/\(tweetResult.id)")
        return PostResult(success: true, postID: tweetResult.id, postURL: postURL, error: nil)
    }
    
    // MARK: - Media Upload (v1.1 with OAuth 1.0a signing)
    
    private func uploadMedia(imageData: Data, signer: OAuth1Signer) async throws -> String {
        let url = URL(string: "https://upload.twitter.com/1.1/media/upload.json")!
        
        // Use MultipartFormBuilder for constructing the body
        var builder = MultipartFormBuilder()
        builder.addJPEGImage(name: "media", data: imageData)
        
        let (body, contentType) = builder.build()
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        // Sign with OAuth 1.0a (multipart body is NOT included in signature base)
        let signedRequest = signer.sign(request)
        
        let (data, response) = try await URLSession.shared.data(for: signedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("Media upload failed (\(statusCode)): \(errorBody)")
            throw PlatformError.postFailed("Media upload failed (\(statusCode)): \(errorBody)")
        }
        
        struct MediaResponse: Decodable {
            let media_id_string: String
        }
        
        let mediaResponse = try JSONDecoder().decode(MediaResponse.self, from: data)
        logger.info("Media uploaded: \(mediaResponse.media_id_string)")
        return mediaResponse.media_id_string
    }
    
    // MARK: - Tweet Creation (v2 with OAuth 1.0a signing)
    
    private func createTweet(text: String, mediaID: String?, signer: OAuth1Signer) async throws -> (id: String, text: String) {
        let url = URL(string: "https://api.twitter.com/2/tweets")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = ["text": text]
        if let mediaID = mediaID {
            payload["media"] = ["media_ids": [mediaID]]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        // Sign with OAuth 1.0a (JSON body is NOT included in signature base)
        let signedRequest = signer.sign(request)
        
        let (data, response) = try await URLSession.shared.data(for: signedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("Tweet creation failed (\(statusCode)): \(errorBody)")
            print("[Twitter] Tweet creation failed (\(statusCode)): \(errorBody)")
            throw PlatformError.postFailed("Tweet creation failed (\(statusCode)): \(errorBody)")
        }
        
        struct TweetResponse: Decodable {
            struct Data: Decodable {
                let id: String
                let text: String
            }
            let data: Data
        }
        
        let tweetResponse = try JSONDecoder().decode(TweetResponse.self, from: data)
        return (tweetResponse.data.id, tweetResponse.data.text)
    }
}
