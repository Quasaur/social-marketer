//
//  OAuthManager.swift
//  SocialMarketer
//
//  Generic OAuth 2.0 manager with PKCE support for platform authentication
//

import Foundation
import AuthenticationServices
import CryptoKit
import Combine
import Network // Added Network import

/// Manages OAuth 2.0 authentication flows for all platforms
@MainActor
final class OAuthManager: NSObject, ObservableObject, OAuthServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = OAuthManager()
    
    // MARK: - Published State
    
    @Published var isAuthenticating = false
    @Published var lastError: Error?
    
    // MARK: - Properties
    
    private let logger = Log.oauth
    private var authSession: ASWebAuthenticationSession?
    private var currentContinuation: CheckedContinuation<OAuthTokens, Error>?
    
    // MARK: - OAuth Configurations
    
    struct OAuthConfig {
        let platformID: String
        var clientID: String
        var clientSecret: String?
        let authURL: URL
        let tokenURL: URL
        let redirectURI: String
        let scopes: [String]
        let usePKCE: Bool
        
        static func twitter(clientID: String) -> OAuthConfig {
            OAuthConfig(
                platformID: "twitter",
                clientID: clientID,
                clientSecret: nil,
                authURL: URL(string: "https://twitter.com/i/oauth2/authorize")!,
                tokenURL: URL(string: "https://api.twitter.com/2/oauth2/token")!,
                redirectURI: "socialmarketer://oauth/callback",
                scopes: ["tweet.read", "tweet.write", "users.read", "media.write", "offline.access"],
                usePKCE: true
            )
        }
        
        static func linkedin(clientID: String, clientSecret: String) -> OAuthConfig {
            OAuthConfig(
                platformID: "linkedin",
                clientID: clientID,
                clientSecret: clientSecret,
                authURL: URL(string: "https://www.linkedin.com/oauth/v2/authorization")!,
                tokenURL: URL(string: "https://www.linkedin.com/oauth/v2/accessToken")!,
                redirectURI: "\(AppConfiguration.URLs.socialEffects)/oauth/callback",
                scopes: ["openid", "profile", "w_member_social"],
                usePKCE: false
            )
        }
        
        static func facebook(clientID: String, clientSecret: String) -> OAuthConfig {
            OAuthConfig(
                platformID: "facebook",
                clientID: clientID,
                clientSecret: clientSecret,
                authURL: URL(string: "https://www.facebook.com/v24.0/dialog/oauth")!,
                tokenURL: URL(string: "https://graph.facebook.com/v24.0/oauth/access_token")!,
                redirectURI: "\(AppConfiguration.URLs.socialEffects)/oauth/callback",
                scopes: ["pages_show_list", "pages_manage_posts", "pages_read_engagement", "business_management"],
                usePKCE: false
            )
        }
        
        static func instagram(clientID: String, clientSecret: String) -> OAuthConfig {
            OAuthConfig(
                platformID: "instagram",
                clientID: clientID,
                clientSecret: clientSecret,
                authURL: URL(string: "https://www.facebook.com/v24.0/dialog/oauth")!,
                tokenURL: URL(string: "https://graph.facebook.com/v24.0/oauth/access_token")!,
                redirectURI: "\(AppConfiguration.URLs.socialEffects)/oauth/callback",
                scopes: ["instagram_basic", "instagram_content_publish", "pages_show_list", "pages_read_engagement", "business_management"],
                usePKCE: false
            )
        }
        
        static func pinterest(clientID: String, clientSecret: String) -> OAuthConfig {
            OAuthConfig(
                platformID: "pinterest",
                clientID: clientID,
                clientSecret: clientSecret,
                authURL: URL(string: "https://www.pinterest.com/oauth/")!,
                tokenURL: URL(string: "https://api.pinterest.com/v5/oauth/token")!,
                redirectURI: "\(AppConfiguration.URLs.socialEffects)/oauth/callback",
                scopes: ["boards:read", "boards:write", "pins:read", "pins:write"],
                usePKCE: false
            )
        }
        
        static func youtube(clientID: String, clientSecret: String) -> OAuthConfig {
            OAuthConfig(
                platformID: "youtube",
                clientID: clientID,
                clientSecret: clientSecret,
                authURL: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
                tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
                redirectURI: "\(AppConfiguration.URLs.socialEffects)/oauth/callback",
                scopes: ["https://www.googleapis.com/auth/youtube.upload"],
                usePKCE: false
            )
        }
    }
    
    // MARK: - API Credentials (stored in Keychain)
    
    struct APICredentials: Codable {
        let clientID: String
        let clientSecret: String?
    }
    
    // MARK: - Twitter OAuth 1.0a Credentials
    
    struct TwitterOAuth1Credentials: Codable {
        let consumerKey: String
        let consumerSecret: String
        let accessToken: String
        let accessTokenSecret: String
    }
    
    /// Save Twitter OAuth 1.0a credentials (4 keys from Developer Portal)
    func saveTwitterOAuth1Credentials(_ creds: TwitterOAuth1Credentials) throws {
        try KeychainService.shared.save(creds, for: "twitter_oauth1")
        logger.info("Twitter OAuth 1.0a credentials saved")
    }
    
    /// Get Twitter OAuth 1.0a credentials
    func getTwitterOAuth1Credentials() throws -> TwitterOAuth1Credentials {
        return try KeychainService.shared.retrieve(TwitterOAuth1Credentials.self, for: "twitter_oauth1")
    }
    
    /// Check if Twitter OAuth 1.0a credentials exist
    func hasTwitterOAuth1Credentials() -> Bool {
        return (try? getTwitterOAuth1Credentials()) != nil
    }
    
    /// Remove Twitter OAuth 1.0a credentials
    func removeTwitterOAuth1Credentials() throws {
        try KeychainService.shared.delete(for: "twitter_oauth1")
        logger.info("Twitter OAuth 1.0a credentials removed")
    }
    
    /// Save API credentials for a platform
    func saveAPICredentials(_ creds: APICredentials, for platform: String) throws {
        try KeychainService.shared.save(creds, for: "api_creds_\(platform)")
        logger.info("API credentials saved for \(platform)")
    }
    
    /// Get API credentials for a platform
    func getAPICredentials(for platform: String) throws -> APICredentials {
        return try KeychainService.shared.retrieve(APICredentials.self, for: "api_creds_\(platform)")
    }
    
    /// Check if API credentials exist for a platform
    func hasAPICredentials(for platform: String) -> Bool {
        return (try? getAPICredentials(for: platform)) != nil
    }
    
    /// Build OAuth config for a platform using stored credentials
    func getConfig(for platform: String) throws -> OAuthConfig {
        let creds = try getAPICredentials(for: platform)
        
        switch platform {
        case "twitter":
            return .twitter(clientID: creds.clientID)
        case "linkedin":
            guard let secret = creds.clientSecret else {
                throw OAuthError.missingCredentials("LinkedIn requires Client Secret")
            }
            return .linkedin(clientID: creds.clientID, clientSecret: secret)
        case "facebook":
            guard let secret = creds.clientSecret else {
                throw OAuthError.missingCredentials("Facebook requires App Secret")
            }
            return .facebook(clientID: creds.clientID, clientSecret: secret)
        case "instagram":
            guard let secret = creds.clientSecret else {
                throw OAuthError.missingCredentials("Instagram requires App Secret")
            }
            return .instagram(clientID: creds.clientID, clientSecret: secret)
        case "pinterest":
            guard let secret = creds.clientSecret else {
                throw OAuthError.missingCredentials("Pinterest requires App Secret")
            }
            return .pinterest(clientID: creds.clientID, clientSecret: secret)
        case "youtube":
            guard let secret = creds.clientSecret else {
                throw OAuthError.missingCredentials("YouTube requires Client Secret")
            }
            return .youtube(clientID: creds.clientID, clientSecret: secret)
        default:
            throw OAuthError.missingCredentials("Unknown platform: \(platform)")
        }
    }
    
    // MARK: - Token Storage
    
    struct OAuthTokens: Codable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Date?
        let tokenType: String
        let scope: String?
        let idToken: String?
        
        var isExpired: Bool {
            guard let expiresAt = expiresAt else { return false }
            return Date() >= expiresAt
        }
    }
    
    // MARK: - PKCE Support
    
    private struct PKCECredentials {
        let verifier: String
        let challenge: String
        
        static func generate() -> PKCECredentials {
            // Generate random verifier (43-128 characters, URL-safe)
            var buffer = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
            let verifier = Data(buffer).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            
            // Generate challenge (SHA256 hash of verifier, base64url encoded)
            let verifierData = Data(verifier.utf8)
            let hash = SHA256.hash(data: verifierData)
            let challenge = Data(hash).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            
            return PKCECredentials(verifier: verifier, challenge: challenge)
        }
    }
    
    private var currentPKCE: PKCECredentials?
    
    // MARK: - Public Methods
    
    /// Start OAuth flow for a platform
    func authenticate(platform: String, config: OAuthConfig) async throws -> OAuthTokens {
        guard !config.clientID.isEmpty else {
            throw OAuthError.missingCredentials("Client ID not configured for \(platform)")
        }
        
        isAuthenticating = true
        defer { isAuthenticating = false }
        
        // Generate PKCE if required
        if config.usePKCE {
            currentPKCE = PKCECredentials.generate()
        }
        
        // Build authorization URL
        let authURL = buildAuthorizationURL(config: config)
        
        logger.info("Starting OAuth flow for \(platform)")
        
        // LinkedIn requires HTTP redirect — use localhost server flow
        if config.redirectURI.starts(with: "http://localhost") || config.redirectURI.starts(with: "http://127.0.0.1") {
            return try await localhostAuthenticate(authURL: authURL, config: config)
        }
        
        // Use ASWebAuthenticationSession for other platforms (custom URL scheme)
        return try await withCheckedThrowingContinuation { continuation in
            self.currentContinuation = continuation
            
            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "socialmarketer"
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.logger.error("OAuth error: \(error.localizedDescription)")
                    self.currentContinuation?.resume(throwing: OAuthError.authenticationFailed(error.localizedDescription))
                    self.currentContinuation = nil
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    self.currentContinuation?.resume(throwing: OAuthError.noCallback)
                    self.currentContinuation = nil
                    return
                }
                
                // Extract authorization code
                Task {
                    do {
                        let tokens = try await self.exchangeCodeForTokens(callbackURL: callbackURL, config: config)
                        self.currentContinuation?.resume(returning: tokens)
                    } catch {
                        self.currentContinuation?.resume(throwing: error)
                    }
                    self.currentContinuation = nil
                }
            }
            
            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.start()
        }
    }
    
    // MARK: - Localhost OAuth Flow
    
    /// OAuth flow using a temporary local HTTP server (for platforms that require HTTP redirect URLs)
    private func localhostAuthenticate(authURL: URL, config: OAuthConfig) async throws -> OAuthTokens {
        // Parse port from redirect URI
        guard let redirectComponents = URLComponents(string: config.redirectURI),
              let port = redirectComponents.port else {
            throw OAuthError.authenticationFailed("Invalid localhost redirect URI")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            // Safety flag to prevent double-resume of continuation
            var continuationResumed = false
            
            // Start a temporary TCP listener on the redirect port
            let listener: NWListener
            do {
                let params = NWParameters.tcp
                params.allowLocalEndpointReuse = true
                listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: UInt16(port)))
            } catch {
                continuation.resume(throwing: OAuthError.authenticationFailed("Failed to start local server: \(error.localizedDescription)"))
                return
            }
            
            listener.newConnectionHandler = { [weak self] connection in
                guard let self = self else { return }
                
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                    guard let data = data, let requestString = String(data: data, encoding: .utf8) else {
                        connection.cancel()
                        return
                    }
                    
                    // Parse the HTTP request line
                    // GET /oauth/callback?code=XXX&state=YYY HTTP/1.1
                    guard let firstLine = requestString.components(separatedBy: "\r\n").first,
                          let path = firstLine.components(separatedBy: " ").dropFirst().first else {
                        connection.cancel()
                        return
                    }
                    
                    // Only process requests to the OAuth callback path — ignore favicon etc.
                    guard path.hasPrefix("/oauth/callback") else {
                        self.sendHTTPResponse(connection: connection, body: "")
                        return
                    }
                    
                    guard !continuationResumed else {
                        connection.cancel()
                        return
                    }
                    
                    guard let callbackURL = URL(string: "http://localhost:\(port)\(path)") else {
                        self.sendHTTPResponse(connection: connection, body: "Error: Could not parse callback.")
                        listener.cancel()
                        if !continuationResumed {
                            continuationResumed = true
                            continuation.resume(throwing: OAuthError.noCallback)
                        }
                        return
                    }
                    
                    // Check for OAuth error in callback (LinkedIn sends errors this way)
                    let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
                    if let error = callbackComponents?.queryItems?.first(where: { $0.name == "error" })?.value {
                        let errorDesc = callbackComponents?.queryItems?.first(where: { $0.name == "error_description" })?.value ?? error
                        self.logger.error("OAuth error from provider: \(error) - \(errorDesc)")
                        self.sendHTTPResponse(connection: connection, body: """
                            <html><body style="font-family:-apple-system,sans-serif;text-align:center;padding:60px;">
                            <h1>❌ Authorization Failed</h1>
                            <p>\(errorDesc)</p>
                            <p style="color:#888;font-size:14px;">You can close this tab and try again in Social Marketer.</p>
                            </body></html>
                        """)
                        listener.cancel()
                        if !continuationResumed {
                            continuationResumed = true
                            continuation.resume(throwing: OAuthError.authenticationFailed(errorDesc))
                        }
                        return
                    }
                    
                    // Verify code parameter exists before showing success
                    guard callbackComponents?.queryItems?.first(where: { $0.name == "code" })?.value != nil else {
                        self.sendHTTPResponse(connection: connection, body: """
                            <html><body style="font-family:-apple-system,sans-serif;text-align:center;padding:60px;">
                            <h1>❌ No Authorization Code</h1>
                            <p>The provider did not return an authorization code.</p>
                            </body></html>
                        """)
                        listener.cancel()
                        if !continuationResumed {
                            continuationResumed = true
                            continuation.resume(throwing: OAuthError.noAuthorizationCode)
                        }
                        return
                    }
                    
                    // Send a friendly success page to the browser
                    self.sendHTTPResponse(connection: connection, body: """
                        <html><body style="font-family:-apple-system,sans-serif;text-align:center;padding:60px;">
                        <h1>✅ Connected!</h1>
                        <p>You can close this tab and return to Social Marketer.</p>
                        </body></html>
                    """)
                    
                    // Stop the listener
                    listener.cancel()
                    
                    // Exchange code for tokens
                    Task {
                        do {
                            let tokens = try await self.exchangeCodeForTokens(callbackURL: callbackURL, config: config)
                            if !continuationResumed {
                                continuationResumed = true
                                continuation.resume(returning: tokens)
                            }
                        } catch {
                            if !continuationResumed {
                                continuationResumed = true
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                }
            }
            
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    // Server is ready — open the browser
                    self?.logger.info("Localhost OAuth server listening on port \(port)")
                    NSWorkspace.shared.open(authURL)
                case .failed(let error):
                    self?.logger.error("Localhost server failed: \(error.localizedDescription)")
                    if !continuationResumed {
                        continuationResumed = true
                        continuation.resume(throwing: OAuthError.authenticationFailed("Local server failed: \(error.localizedDescription)"))
                    }
                default:
                    break
                }
            }
            
            listener.start(queue: .main)
            
            // Timeout after 5 minutes
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                if listener.state == .ready {
                    listener.cancel()
                    if !continuationResumed {
                        continuationResumed = true
                        continuation.resume(throwing: OAuthError.authenticationFailed("OAuth timed out — no callback received"))
                    }
                }
            }
        }
    }
    
    /// Send an HTTP response and close the connection
    private func sendHTTPResponse(connection: NWConnection, body: String) {
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    /// Refresh an expired token
    func refreshToken(refreshToken: String, config: OAuthConfig) async throws -> OAuthTokens {
        var request = URLRequest(url: config.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": config.clientID
        ]
        
        if let secret = config.clientSecret {
            body["client_secret"] = secret
        }
        
        request.httpBody = body.percentEncoded()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OAuthError.tokenRefreshFailed
        }
        
        return try parseTokenResponse(data: data)
    }
    
    /// Save tokens to Keychain for a platform
    func saveTokens(_ tokens: OAuthTokens, for platform: String) throws {
        try KeychainService.shared.save(tokens, for: "oauth_\(platform)")
        logger.info("Tokens saved for \(platform)")
    }
    
    /// Retrieve tokens from Keychain for a platform
    func getTokens(for platform: String) throws -> OAuthTokens {
        return try KeychainService.shared.retrieve(OAuthTokens.self, for: "oauth_\(platform)")
    }
    
    /// Check if a platform has valid tokens
    func hasValidTokens(for platform: String) -> Bool {
        guard let tokens = try? getTokens(for: platform) else { return false }
        return !tokens.isExpired
    }
    
    /// Remove tokens for a platform
    func removeTokens(for platform: String) throws {
        try KeychainService.shared.delete(for: "oauth_\(platform)")
        logger.info("Tokens removed for \(platform)")
    }
    
    // MARK: - Private Methods
    
    private func buildAuthorizationURL(config: OAuthConfig) -> URL {
        var components = URLComponents(url: config.authURL, resolvingAgainstBaseURL: false)!
        
        var queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: UUID().uuidString)
        ]
        
        if config.usePKCE, let pkce = currentPKCE {
            queryItems.append(URLQueryItem(name: "code_challenge", value: pkce.challenge))
            queryItems.append(URLQueryItem(name: "code_challenge_method", value: "S256"))
        }
        
        // Force re-consent for LinkedIn to ensure all scopes are granted
        if config.redirectURI.starts(with: "http://localhost") {
            queryItems.append(URLQueryItem(name: "prompt", value: "consent"))
        }
        
        components.queryItems = queryItems
        return components.url!
    }
    
    private func exchangeCodeForTokens(callbackURL: URL, config: OAuthConfig) async throws -> OAuthTokens {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.noAuthorizationCode
        }
        
        var request = URLRequest(url: config.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Pinterest requires Basic Authentication header for token exchange
        if config.platformID == "pinterest", let secret = config.clientSecret {
            let credentials = "\(config.clientID):\(secret)"
            if let credentialsData = credentials.data(using: .utf8) {
                let base64Credentials = credentialsData.base64EncodedString()
                request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
            }
        }
        
        var body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI
        ]
        
        // Pinterest uses Basic Auth, so don't include client_id/secret in body
        if config.platformID != "pinterest" {
            body["client_id"] = config.clientID
            if let secret = config.clientSecret {
                body["client_secret"] = secret
            }
        }
        
        if config.usePKCE, let pkce = currentPKCE {
            body["code_verifier"] = pkce.verifier
        }
        
        request.httpBody = body.percentEncoded()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Token exchange failed: \(errorBody)")
            throw OAuthError.tokenExchangeFailed(errorBody)
        }
        
        currentPKCE = nil
        return try parseTokenResponse(data: data)
    }
    
    private func parseTokenResponse(data: Data) throws -> OAuthTokens {
        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int?
            let token_type: String?
            let scope: String?
            let id_token: String?
        }
        
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        let expiresAt: Date?
        if let expiresIn = response.expires_in {
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            expiresAt = nil
        }
        
        return OAuthTokens(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            expiresAt: expiresAt,
            tokenType: response.token_type ?? "Bearer",
            scope: response.scope,
            idToken: response.id_token
        )
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}

// MARK: - Errors

enum OAuthError: Error, LocalizedError {
    case missingCredentials(String)
    case authenticationFailed(String)
    case noCallback
    case noAuthorizationCode
    case tokenExchangeFailed(String)
    case tokenRefreshFailed
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials(let message):
            return "Missing credentials: \(message)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .noCallback:
            return "No callback URL received"
        case .noAuthorizationCode:
            return "No authorization code in callback"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .tokenRefreshFailed:
            return "Failed to refresh token"
        }
    }
}

// MARK: - Dictionary Extension

private extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data {
        // Use strict RFC 3986 unreserved characters for form-urlencoded encoding
        // This properly encodes +, /, =, etc. that appear in OAuth secrets
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        
        return map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)!
    }
}
