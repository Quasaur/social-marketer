//
//  FileUploadService.swift
//  SocialMarketer
//
//  Uploads video files to public hosting service for Instagram access
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "FileUpload")

/// Service for uploading files to public hosting
/// Used to create publicly accessible URLs for Instagram video uploads
final class FileUploadService {
    static let shared = FileUploadService()
    
    private init() {}
    
    /// Uploads a video file to transfer.sh and returns the public URL
    /// - Parameter fileURL: Local file URL to upload
    /// - Returns: Public URL that Instagram can access
    func uploadVideo(_ fileURL: URL) async throws -> String {
        logger.info("Uploading video to transfer.sh: \(fileURL.lastPathComponent)")
        
        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw PlatformError.postFailed("Failed to read video file: \(error.localizedDescription)")
        }
        
        let fileName = fileURL.lastPathComponent
        
        // Create upload request to transfer.sh
        let uploadURL = URL(string: "https://transfer.sh/\(fileName)")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("max-age=3600", forHTTPHeaderField: "Max-Days") // 1 day retention
        
        logger.info("Uploading \(fileData.count / 1024 / 1024) MB to transfer.sh...")
        
        // Perform upload with timeout
        let (data, response) = try await URLSession.shared.upload(for: request, from: fileData)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PlatformError.postFailed("Upload failed with status: \(statusCode)")
        }
        
        guard let publicURL = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              publicURL.hasPrefix("https://") else {
            throw PlatformError.postFailed("Invalid response from upload service")
        }
        
        logger.info("Upload complete. Public URL: \(publicURL)")
        
        // Verify the URL is accessible
        try await verifyURLAccessible(publicURL)
        
        return publicURL
    }
    
    /// Verifies the uploaded URL is accessible
    private func verifyURLAccessible(_ urlString: String) async throws {
        logger.info("Verifying URL accessibility...")
        
        guard let url = URL(string: urlString) else {
            throw PlatformError.postFailed("Invalid URL format")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PlatformError.postFailed("URL not accessible (status: \(statusCode))")
        }
        
        logger.info("URL verified accessible")
    }
    
    /// Alternative: Upload to 0x0.st (no expiration, simpler)
    func uploadVideoTo0x0(_ fileURL: URL) async throws -> String {
        logger.info("Uploading video to 0x0.st: \(fileURL.lastPathComponent)")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://0x0.st")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        
        // Add file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        logger.info("Uploading \(fileData.count / 1024 / 1024) MB to 0x0.st...")
        
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PlatformError.postFailed("Upload failed with status: \(statusCode)")
        }
        
        guard let publicURL = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              publicURL.hasPrefix("https://") else {
            throw PlatformError.postFailed("Invalid response from upload service")
        }
        
        logger.info("Upload complete. Public URL: \(publicURL)")
        
        // 0x0.st URLs need a moment to propagate
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        return publicURL
    }
}
