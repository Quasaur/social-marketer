//
//  MultipartFormBuilder.swift
//  SocialMarketer
//
//  Builder pattern for constructing multipart/form-data HTTP bodies.
//  Eliminates duplication across platform connectors.
//

import Foundation

/// Builder for constructing multipart/form-data request bodies
///
/// Usage:
/// ```swift
/// var builder = MultipartFormBuilder()
/// builder.addField(name: "access_token", value: token)
/// builder.addField(name: "message", value: caption)
/// builder.addFile(name: "source", filename: "image.jpg", contentType: "image/jpeg", data: imageData)
/// let (body, contentType) = builder.build()
/// request.httpBody = body
/// request.setValue(contentType, forHTTPHeaderField: "Content-Type")
/// ```
struct MultipartFormBuilder {
    private var body = Data()
    private let boundary: String
    
    /// Initialize with optional custom boundary
    /// - Parameter boundary: Unique boundary string (defaults to UUID)
    init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }
    
    /// The boundary string used for this builder
    var currentBoundary: String { boundary }
    
    /// Add a text field to the form
    /// - Parameters:
    ///   - name: Field name
    ///   - value: Field value
    mutating func addField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append(value)
        append("\r\n")
    }
    
    /// Add a file attachment to the form
    /// - Parameters:
    ///   - name: Field name
    ///   - filename: Filename to send
    ///   - contentType: MIME type (e.g., "image/jpeg", "video/mp4")
    ///   - data: Binary file data
    mutating func addFile(name: String, filename: String, contentType: String, data: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }
    
    /// Build the final request body and content type header value
    /// - Returns: Tuple of (body data, Content-Type header value)
    func build() -> (body: Data, contentType: String) {
        var finalBody = body
        append(&finalBody, "--\(boundary)--\r\n")
        return (finalBody, "multipart/form-data; boundary=\(boundary)")
    }
    
    // MARK: - Private Helpers
    
    private mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            body.append(data)
        }
    }
    
    private func append(_ data: inout Data, _ string: String) {
        if let stringData = string.data(using: .utf8) {
            data.append(stringData)
        }
    }
}

// MARK: - Convenience Extensions

extension MultipartFormBuilder {
    /// Add an image file with JPEG content type
    /// - Parameters:
    ///   - name: Field name (typically "source" or "media")
    ///   - filename: Filename (e.g., "image.jpg")
    ///   - data: JPEG image data
    mutating func addJPEGImage(name: String, filename: String = "image.jpg", data: Data) {
        addFile(name: name, filename: filename, contentType: "image/jpeg", data: data)
    }
    
    /// Add a video file with MP4 content type
    /// - Parameters:
    ///   - name: Field name (typically "source" or "video")
    ///   - filename: Filename (e.g., "video.mp4")
    ///   - data: MP4 video data
    mutating func addMP4Video(name: String, filename: String = "video.mp4", data: Data) {
        addFile(name: name, filename: filename, contentType: "video/mp4", data: data)
    }
    
    /// Add a PNG image file
    /// - Parameters:
    ///   - name: Field name
    ///   - filename: Filename (e.g., "image.png")
    ///   - data: PNG image data
    mutating func addPNGImage(name: String, filename: String = "image.png", data: Data) {
        addFile(name: name, filename: filename, contentType: "image/png", data: data)
    }
}
