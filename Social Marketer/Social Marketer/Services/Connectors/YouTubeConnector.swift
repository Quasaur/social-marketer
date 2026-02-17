//
//  YouTubeConnector.swift
//  SocialMarketer
//
//  Created by Automation on 2026-02-16.
//

import Foundation
import AppKit
import AVFoundation

// MARK: - YouTube Connector

final class YouTubeConnector: VideoPlatformConnector {
    let platformName = "YouTube"
    private let logger = Log.youtube
    private var accessToken: String?
    private var refreshToken: String?
    
    var isConfigured: Bool {
        get async {
            return loadCredentials() != nil
        }
    }
    
    func authenticate() async throws {
        let oauth = OAuthManager.shared
        let config = try oauth.getConfig(for: "youtube")
        
        logger.info("Starting YouTube OAuth flow")
        let tokens = try await oauth.authenticate(platform: "youtube", config: config)
        
        // Store tokens
        try oauth.saveTokens(tokens, for: "youtube")
        
        let creds = PlatformCredentials.YouTubeCredentials(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken
        )
        saveCredentials(creds)
        
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        
        logger.info("YouTube authenticated successfully")
    }
    
    func postText(_ text: String) async throws -> PostResult {
        // YouTube requires video content, text-only not supported
        throw PlatformError.notImplemented
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let accessToken = accessToken ?? loadCredentials()?.accessToken else {
            throw PlatformError.notConfigured
        }
        
        logger.info("Converting image to YouTube Short")
        
        // Generate YouTube Short (vertical 9:16, 3 seconds, 30fps)
        let videoURL = try await generateShort(from: image)
        defer {
            // Clean up temp file
            try? FileManager.default.removeItem(at: videoURL)
        }
        
        // Upload to YouTube as Short
        let videoID = try await uploadVideo(
            videoURL: videoURL,
            title: extractTitle(from: caption),
            description: "\(caption)\n\n\(link.absoluteString)\n\n#Shorts",
            accessToken: accessToken
        )
        
        logger.info("YouTube Short uploaded: \(videoID)")
        
        let postURL = URL(string: "https://www.youtube.com/shorts/\(videoID)")
        return PostResult(success: true, postID: videoID, postURL: postURL, error: nil)
    }
    
    func postVideo(_ videoURL: URL, caption: String) async throws -> PostResult {
        guard let accessToken = accessToken ?? loadCredentials()?.accessToken else {
            throw PlatformError.notConfigured
        }
        
        logger.info("Uploading video to YouTube...")
        
        // Upload to YouTube
        // We add #Shorts to description to help YouTube classify vertical videos as Shorts,
        // though it mostly depends on aspect ratio/duration.
        let videoID = try await uploadVideo(
            videoURL: videoURL,
            title: extractTitle(from: caption),
            description: "\(caption)\n\n#Shorts #SocialMarketer",
            accessToken: accessToken
        )
        
        logger.info("YouTube video uploaded: \(videoID)")
        
        // Return URL (regular watch URL work for shorts too)
        let postURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)")
        return PostResult(success: true, postID: videoID, postURL: postURL, error: nil)
    }
    
    // MARK: - YouTube Short Generation
    
    /// Generate a YouTube Short (vertical 9:16 format, 3 seconds)
    private func generateShort(from image: NSImage) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            
            guard let writer = try? AVAssetWriter(url: tempURL, fileType: .mp4) else {
                continuation.resume(throwing: PlatformError.postFailed("Failed to create video writer"))
                return
            }
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1080,   // Shorts: 1080x1920 (9:16 vertical)
                AVVideoHeightKey: 1920
            ]
            
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                    kCVPixelBufferWidthKey as String: 1080,
                    kCVPixelBufferHeightKey as String: 1920
                ]
            )
            
            writer.add(writerInput)
            
            guard writer.startWriting() else {
                continuation.resume(throwing: PlatformError.postFailed("Failed to start writing video"))
                return
            }
            
            writer.startSession(atSourceTime: .zero)
            
            // Generate 90 frames (3 seconds at 30fps)
            let frameDuration = CMTime(value: 1, timescale: 30)
            var frameCount = 0
            let totalFrames = 90
            
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "videoQueue")) {
                while writerInput.isReadyForMoreMediaData && frameCount < totalFrames {
                    let presentationTime = CMTime(value: Int64(frameCount), timescale: 30)
                    
                    if let pixelBuffer = self.pixelBuffer(from: image, size: CGSize(width: 1080, height: 1920)) {
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }
                    
                    frameCount += 1
                }
                
                if frameCount >= totalFrames {
                    writerInput.markAsFinished()
                    writer.finishWriting {
                        if writer.status == .completed {
                            continuation.resume(returning: tempURL)
                        } else {
                            continuation.resume(throwing: PlatformError.postFailed("Video encoding failed"))
                        }
                    }
                }
            }
        }
    }
    
    private func pixelBuffer(from image: NSImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        context?.draw(
            image.cgImage(forProposedRect: nil, context: nil, hints: nil)!,
            in: CGRect(origin: .zero, size: size)
        )
        
        return buffer
    }
    
    // MARK: - Upload
    
    private func uploadVideo(videoURL: URL, title: String, description: String, accessToken: String) async throws -> String {
        let videoData = try Data(contentsOf: videoURL)
        
        // Create metadata JSON
        let metadata: [String: Any] = [
            "snippet": [
                "title": title,
                "description": description
            ],
            "status": [
                "privacyStatus": "public"
            ]
        ]
        
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        
        // Build multipart request
        let boundary = "----boundary\(UUID().uuidString)"
        var body = Data()
        
        // Part 1: JSON metadata
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Part 2: Video binary
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Make request
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=multipart&part=snippet,status")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlatformError.postFailed("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("YouTube upload failed (\(httpResponse.statusCode)): \(errorBody)")
            throw PlatformError.postFailed("Upload failed (\(httpResponse.statusCode)): \(errorBody)")
        }
        
        struct UploadResponse: Decodable {
            let id: String
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.id
    }
    
    // MARK: - Helpers
    
    private func extractTitle(from caption: String) -> String {
        // Extract first line or first 100 chars as title
        let lines = caption.components(separatedBy: .newlines)
        let title = lines.first ?? caption
        return String(title.prefix(100))
    }
    
    private func loadCredentials() -> PlatformCredentials.YouTubeCredentials? {
        guard let tokens = try? OAuthManager.shared.getTokens(for: "youtube") else { return nil }
        return PlatformCredentials.YouTubeCredentials(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken
        )
    }
    
    private func saveCredentials(_ creds: PlatformCredentials.YouTubeCredentials) {
        accessToken = creds.accessToken
        refreshToken = creds.refreshToken
    }
}
