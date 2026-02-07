//
//  GoogleIndexingConnector.swift
//  SocialMarketer
//
//  Google Search Console Indexing API connector
//  Uses service account JWT authentication
//

import Foundation
import os.log

/// Notifies Google Search Console when wisdombook.life URLs are published or updated
final class GoogleIndexingConnector {
    
    private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "GoogleIndexing")
    
    // MARK: - Configuration
    
    private static let indexingAPIURL = "https://indexing.googleapis.com/v3/urlNotifications:publish"
    private static let statusAPIURL = "https://indexing.googleapis.com/v3/urlNotifications/metadata"
    private static let tokenURL = "https://oauth2.googleapis.com/token"
    private static let indexingScope = "https://www.googleapis.com/auth/indexing"
    
    private static let keyFileName = "gsc_service_account.json"
    
    /// App Support directory for storing the service account key
    private static var appSupportURL: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SocialMarketer")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    private static var storedKeyURL: URL {
        appSupportURL.appendingPathComponent(keyFileName)
    }
    
    // MARK: - Token Cache
    
    private var cachedAccessToken: String?
    private var tokenExpiresAt: Date?
    
    // MARK: - Service Account Key
    
    struct ServiceAccountKey: Codable {
        let type: String
        let projectID: String
        let privateKeyID: String
        let privateKey: String
        let clientEmail: String
        let clientID: String
        let authURI: String
        let tokenURI: String
        
        enum CodingKeys: String, CodingKey {
            case type
            case projectID = "project_id"
            case privateKeyID = "private_key_id"
            case privateKey = "private_key"
            case clientEmail = "client_email"
            case clientID = "client_id"
            case authURI = "auth_uri"
            case tokenURI = "token_uri"
        }
    }
    
    // MARK: - Public Properties
    
    /// Whether a service account key has been imported
    var isConfigured: Bool {
        FileManager.default.fileExists(atPath: Self.storedKeyURL.path)
    }
    
    /// The configured service account email, if available
    var serviceAccountEmail: String? {
        guard let key = loadServiceAccountKey() else { return nil }
        return key.clientEmail
    }
    
    // MARK: - Key Management
    
    /// Import a service account JSON key file
    func importServiceAccountKey(from sourceURL: URL) throws {
        // Validate the JSON file
        let data = try Data(contentsOf: sourceURL)
        let key = try JSONDecoder().decode(ServiceAccountKey.self, from: data)
        
        guard key.type == "service_account" else {
            throw GoogleIndexingError.invalidKeyFile("Expected type 'service_account', got '\(key.type)'")
        }
        
        guard !key.privateKey.isEmpty else {
            throw GoogleIndexingError.invalidKeyFile("Private key is empty")
        }
        
        guard !key.clientEmail.isEmpty else {
            throw GoogleIndexingError.invalidKeyFile("Client email is empty")
        }
        
        // Copy to app support directory
        if FileManager.default.fileExists(atPath: Self.storedKeyURL.path) {
            try FileManager.default.removeItem(at: Self.storedKeyURL)
        }
        try data.write(to: Self.storedKeyURL)
        
        // Clear cached token
        cachedAccessToken = nil
        tokenExpiresAt = nil
        
        logger.info("Service account key imported: \(key.clientEmail)")
    }
    
    /// Remove the stored service account key
    func removeServiceAccountKey() throws {
        if FileManager.default.fileExists(atPath: Self.storedKeyURL.path) {
            try FileManager.default.removeItem(at: Self.storedKeyURL)
        }
        cachedAccessToken = nil
        tokenExpiresAt = nil
        logger.info("Service account key removed")
    }
    
    // MARK: - Indexing API
    
    /// Notify Google that a URL has been updated or created
    func notifyURLUpdated(_ url: URL) async throws {
        try await sendNotification(url: url, type: "URL_UPDATED")
    }
    
    /// Notify Google that a URL has been deleted
    func notifyURLDeleted(_ url: URL) async throws {
        try await sendNotification(url: url, type: "URL_DELETED")
    }
    
    /// Check the notification status for a URL
    func checkStatus(for url: URL) async throws -> URLNotificationStatus {
        let accessToken = try await getAccessToken()
        
        var components = URLComponents(string: Self.statusAPIURL)!
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString)
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleIndexingError.requestFailed("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleIndexingError.requestFailed("Status check failed (\(httpResponse.statusCode)): \(body)")
        }
        
        return try JSONDecoder().decode(URLNotificationStatus.self, from: data)
    }
    
    // MARK: - Private Methods
    
    private func sendNotification(url: URL, type: String) async throws {
        let accessToken = try await getAccessToken()
        
        let apiURL = URL(string: Self.indexingAPIURL)!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: String] = [
            "url": url.absoluteString,
            "type": type
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleIndexingError.requestFailed("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Indexing API error (\(httpResponse.statusCode)): \(body)")
            throw GoogleIndexingError.requestFailed("Notification failed (\(httpResponse.statusCode)): \(body)")
        }
        
        logger.info("✅ Google notified: \(type) → \(url.absoluteString)")
    }
    
    private func loadServiceAccountKey() -> ServiceAccountKey? {
        guard let data = try? Data(contentsOf: Self.storedKeyURL) else { return nil }
        return try? JSONDecoder().decode(ServiceAccountKey.self, from: data)
    }
    
    // MARK: - JWT Authentication
    
    private func getAccessToken() async throws -> String {
        // Return cached token if still valid (with 60s buffer)
        if let token = cachedAccessToken,
           let expires = tokenExpiresAt,
           Date() < expires.addingTimeInterval(-60) {
            return token
        }
        
        guard let key = loadServiceAccountKey() else {
            throw GoogleIndexingError.notConfigured
        }
        
        // Create JWT
        let jwt = try createJWT(serviceAccount: key)
        
        // Exchange JWT for access token
        let token = try await exchangeJWTForToken(jwt: jwt)
        
        return token
    }
    
    private func createJWT(serviceAccount key: ServiceAccountKey) throws -> String {
        let now = Date()
        let expiration = now.addingTimeInterval(3600) // 1 hour
        
        // JWT Header
        let header: [String: String] = [
            "alg": "RS256",
            "typ": "JWT"
        ]
        
        // JWT Claims
        let claims: [String: Any] = [
            "iss": key.clientEmail,
            "scope": Self.indexingScope,
            "aud": Self.tokenURL,
            "iat": Int(now.timeIntervalSince1970),
            "exp": Int(expiration.timeIntervalSince1970)
        ]
        
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let claimsData = try JSONSerialization.data(withJSONObject: claims)
        
        let headerB64 = headerData.base64URLEncoded()
        let claimsB64 = claimsData.base64URLEncoded()
        
        let signatureInput = "\(headerB64).\(claimsB64)"
        
        // Sign with RSA private key
        let signature = try signWithRSA(data: Data(signatureInput.utf8), privateKeyPEM: key.privateKey)
        let signatureB64 = signature.base64URLEncoded()
        
        return "\(headerB64).\(claimsB64).\(signatureB64)"
    }
    
    private func signWithRSA(data: Data, privateKeyPEM: String) throws -> Data {
        // Strip PEM headers and decode
        let pemClean = privateKeyPEM
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        guard let keyData = Data(base64Encoded: pemClean) else {
            throw GoogleIndexingError.invalidKeyFile("Failed to decode private key")
        }
        
        // Google service account keys use PKCS#8 format (BEGIN PRIVATE KEY).
        // Apple's SecKeyCreateWithData expects PKCS#1 (raw RSA key).
        // PKCS#8 wraps the PKCS#1 key with a 26-byte ASN.1 header for RSA 2048.
        // We need to strip this header to get the raw RSA key data.
        let rsaKeyData: Data
        if privateKeyPEM.contains("BEGIN PRIVATE KEY") {
            // PKCS#8 format — strip the ASN.1 header
            // The PKCS#8 header for RSA keys is a fixed sequence:
            // 30 82 xx xx (SEQUENCE) + 02 01 00 (version) + 30 0D 06 09 ... (algorithm OID) + 04 82 xx xx (OCTET STRING wrapper)
            // For 2048-bit RSA keys, the header is 26 bytes
            let pkcs8HeaderLength = 26
            guard keyData.count > pkcs8HeaderLength else {
                throw GoogleIndexingError.invalidKeyFile("Private key data too short for PKCS#8")
            }
            rsaKeyData = keyData.subdata(in: pkcs8HeaderLength..<keyData.count)
        } else {
            // Already PKCS#1 format
            rsaKeyData = keyData
        }
        
        // Create SecKey from PKCS#1 DER data
        let keyDict: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048
        ]
        
        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(rsaKeyData as CFData, keyDict as CFDictionary, &error) else {
            let errorDesc = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw GoogleIndexingError.invalidKeyFile("Failed to create RSA key: \(errorDesc)")
        }
        
        // Sign using SHA256 with RSA
        guard SecKeyIsAlgorithmSupported(secKey, .sign, .rsaSignatureMessagePKCS1v15SHA256) else {
            throw GoogleIndexingError.invalidKeyFile("RSA SHA256 signing not supported")
        }
        
        guard let signedData = SecKeyCreateSignature(
            secKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            data as CFData,
            &error
        ) as Data? else {
            let errorDesc = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw GoogleIndexingError.signingFailed(errorDesc)
        }
        
        return signedData
    }
    
    private func exchangeJWTForToken(jwt: String) async throws -> String {
        let url = URL(string: Self.tokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(jwt)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Token exchange failed: \(errorBody)")
            throw GoogleIndexingError.authenticationFailed(errorBody)
        }
        
        struct TokenResponse: Decodable {
            let access_token: String
            let expires_in: Int
            let token_type: String
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        cachedAccessToken = tokenResponse.access_token
        tokenExpiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        
        logger.info("Access token obtained, expires in \(tokenResponse.expires_in)s")
        
        return tokenResponse.access_token
    }
}

// MARK: - Response Types

struct URLNotificationStatus: Decodable {
    let url: String?
    let latestUpdate: NotificationInfo?
    let latestRemove: NotificationInfo?
    
    struct NotificationInfo: Decodable {
        let url: String?
        let type: String?
        let notifyTime: String?
    }
}

// MARK: - Base64 URL Encoding

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Errors

enum GoogleIndexingError: Error, LocalizedError {
    case notConfigured
    case invalidKeyFile(String)
    case signingFailed(String)
    case authenticationFailed(String)
    case requestFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Google Search Console not configured — import a service account key"
        case .invalidKeyFile(let reason):
            return "Invalid service account key: \(reason)"
        case .signingFailed(let reason):
            return "JWT signing failed: \(reason)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .requestFailed(let reason):
            return "Indexing API request failed: \(reason)"
        }
    }
}
