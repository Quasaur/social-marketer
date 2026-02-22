//
//  BasePlatformConnector.swift
//  SocialMarketer
//
//  Base class for platform connectors providing common HTTP handling,
//  JSON decoding, and error logging functionality.
//

import Foundation

/// Base class for platform connectors providing shared HTTP functionality
///
/// This class eliminates duplicate HTTP response handling, JSON decoding,
/// and error logging code across all platform connectors.
///
/// Usage:
/// ```swift
/// final class MyConnector: BasePlatformConnector, PlatformConnector {
///     override var platformName: String { "MyPlatform" }
///     
///     func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
///         let data = try await performRequest(request)
///         // ... process response
///     }
/// }
/// ```
class BasePlatformConnector {
    
    /// Platform name for logging and error messages
    /// Override this in subclasses
    var platformName: String {
        String(describing: type(of: self)).replacingOccurrences(of: "Connector", with: "")
    }
    
    /// Logger for this platform
    lazy var logger: Logger = {
        // Derive logger from platform name
        switch platformName.lowercased() {
        case "youtube": return Log.youtube
        case "twitter", "x": return Log.twitter
        case "linkedin": return Log.linkedin
        case "facebook": return Log.facebook
        case "instagram": return Log.instagram
        case "pinterest": return Log.pinterest
        case "tiktok": return Log.tiktok
        default: return Log.app
        }
    }()
    
    /// URLSession for network requests
    /// Can be overridden for testing or custom configuration
    var session: URLSession { URLSession.shared }
    
    // MARK: - HTTP Request Helpers
    
    /// Perform an HTTP request and validate the response
    /// - Parameters:
    ///   - request: URLRequest to execute
    ///   - expectedStatus: Expected HTTP status code (default: 200)
    /// - Returns: Response data
    /// - Throws: PlatformError on failure
    func performRequest(_ request: URLRequest, expectedStatus: Int = 200) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlatformError.postFailed("Invalid response from \(platformName)")
        }
        
        guard httpResponse.statusCode == expectedStatus else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let message = "\(platformName) request failed (HTTP \(httpResponse.statusCode)): \(errorBody)"
            logger.error("\(message)")
            ErrorLog.shared.log(category: platformName, message: "Request failed", detail: message)
            throw PlatformError.postFailed(message)
        }
        
        return data
    }
    
    /// Perform a request and decode the JSON response
    /// - Parameters:
    ///   - request: URLRequest to execute
    ///   - type: Expected response type (must be Decodable)
    ///   - expectedStatus: Expected HTTP status code (default: 200)
    /// - Returns: Decoded response object
    /// - Throws: PlatformError on failure or decoding error
    func performJSONRequest<T: Decodable>(
        _ request: URLRequest,
        decoding type: T.Type,
        expectedStatus: Int = 200
    ) async throws -> T {
        let data = try await performRequest(request, expectedStatus: expectedStatus)
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unable to decode"
            logger.error("JSON decoding failed: \(error.localizedDescription). Body: \(errorBody)")
            throw PlatformError.postFailed("\(platformName) response parsing failed: \(error.localizedDescription)")
        }
    }
    
    /// Perform a request and return response as JSON dictionary
    /// - Parameters:
    ///   - request: URLRequest to execute
    ///   - expectedStatus: Expected HTTP status code (default: 200)
    /// - Returns: JSON dictionary (if parsing succeeds)
    /// - Throws: PlatformError on failure
    func performJSONRequest(
        _ request: URLRequest,
        expectedStatus: Int = 200
    ) async throws -> [String: Any] {
        let data = try await performRequest(request, expectedStatus: expectedStatus)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlatformError.postFailed("\(platformName) returned invalid JSON")
        }
        
        return json
    }
    
    // MARK: - OAuth Helpers
    
    /// Get OAuth configuration for this platform
    /// - Throws: PlatformError if configuration is missing
    func getOAuthConfig() throws -> OAuthManager.OAuthConfig {
        do {
            return try OAuthManager.shared.getConfig(for: oauthPlatformID)
        } catch {
            throw PlatformError.notConfigured
        }
    }
    
    /// Authenticate using OAuth and save tokens
    /// - Returns: OAuth tokens
    /// - Throws: PlatformError on authentication failure
    func performOAuthAuthentication() async throws -> OAuthManager.OAuthTokens {
        let config = try getOAuthConfig()
        
        logger.info("Starting \(self.platformName) OAuth flow")
        
        do {
            let tokens = try await OAuthManager.shared.authenticate(
                platform: oauthPlatformID,
                config: config
            )
            try OAuthManager.shared.saveTokens(tokens, for: oauthPlatformID)
            self.logger.info("\(self.platformName) authenticated successfully")
            return tokens
        } catch {
            self.logger.error("\(self.platformName) OAuth failed: \(error.localizedDescription)")
            throw PlatformError.authenticationFailed
        }
    }
    
    /// OAuth platform identifier (override if different from platform name)
    var oauthPlatformID: String {
        platformName.lowercased()
            .replacingOccurrences(of: "x (twitter)", with: "twitter")
            .replacingOccurrences(of: " ", with: "")
    }
    
    // MARK: - Error Helpers
    
    /// Log an error to both the logger and ErrorLog
    /// - Parameters:
    ///   - message: Short error message
    ///   - detail: Optional detailed error information
    func logError(_ message: String, detail: String? = nil) {
        logger.error("\(message)")
        ErrorLog.shared.log(category: platformName, message: message, detail: detail)
    }
    
    /// Log an info message
    /// - Parameter message: Info message
    func logInfo(_ message: String) {
        logger.info("\(message)")
    }
    
    /// Log a debug message (only in debug mode)
    /// - Parameter message: Debug message
    func logDebug(_ message: String) {
        if Log.isDebugMode {
            logger.debug("\(message)")
        }
    }
}

// MARK: - HTTP Method Helpers

extension BasePlatformConnector {
    
    /// Create a GET request
    /// - Parameters:
    ///   - url: Request URL
    ///   - headers: Optional additional headers
    /// - Returns: Configured URLRequest
    func getRequest(url: URL, headers: [String: String]? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
    
    /// Create a POST request
    /// - Parameters:
    ///   - url: Request URL
    ///   - body: Request body data
    ///   - contentType: Content-Type header value
    ///   - headers: Optional additional headers
    /// - Returns: Configured URLRequest
    func postRequest(
        url: URL,
        body: Data? = nil,
        contentType: String? = nil,
        headers: [String: String]? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
    
    /// Create a DELETE request
    /// - Parameters:
    ///   - url: Request URL
    ///   - headers: Optional additional headers
    /// - Returns: Configured URLRequest
    func deleteRequest(url: URL, headers: [String: String]? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }
}
