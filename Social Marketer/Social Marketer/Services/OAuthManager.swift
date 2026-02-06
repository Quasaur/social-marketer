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
import os.log

/// Manages OAuth 2.0 authentication flows for all platforms
@MainActor
final class OAuthManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = OAuthManager()
    
    // MARK: - Published State
    
    @Published var isAuthenticating = false
    @Published var lastError: Error?
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "OAuth")
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
                scopes: ["tweet.read", "tweet.write", "users.read", "offline.access"],
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
                redirectURI: "socialmarketer://oauth/callback",
                scopes: ["w_member_social", "openid", "profile"],
                usePKCE: false
            )
        }
        
        static func facebook(clientID: String, clientSecret: String) -> OAuthConfig {
            OAuthConfig(
                platformID: "facebook",
                clientID: clientID,
                clientSecret: clientSecret,
                authURL: URL(string: "https://www.facebook.com/v19.0/dialog/oauth")!,
                tokenURL: URL(string: "https://graph.facebook.com/v19.0/oauth/access_token")!,
                redirectURI: "socialmarketer://oauth/callback",
                scopes: ["pages_manage_posts", "pages_read_engagement", "instagram_basic", "instagram_content_publish"],
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
                redirectURI: "socialmarketer://oauth/callback",
                scopes: ["boards:read", "pins:write"],
                usePKCE: false
            )
        }
    }
    
    // MARK: - API Credentials (stored in Keychain)
    
    struct APICredentials: Codable {
        let clientID: String
        let clientSecret: String?
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
        case "pinterest":
            guard let secret = creds.clientSecret else {
                throw OAuthError.missingCredentials("Pinterest requires App Secret")
            }
            return .pinterest(clientID: creds.clientID, clientSecret: secret)
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
        
        // Use ASWebAuthenticationSession for secure OAuth
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
        
        var body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": config.redirectURI,
            "client_id": config.clientID
        ]
        
        if let secret = config.clientSecret {
            body["client_secret"] = secret
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
            let token_type: String
            let scope: String?
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
            tokenType: response.token_type,
            scope: response.scope
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
        map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)!
    }
}
