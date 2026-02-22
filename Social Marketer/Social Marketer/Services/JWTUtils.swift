//
//  JWTUtils.swift
//  SocialMarketer
//
//  JWT token decoding utilities
//

import Foundation

/// Utilities for working with JWT (JSON Web Tokens)
enum JWTUtils {
    
    /// JWT decoding errors
    enum JWTError: Error {
        case invalidFormat
        case invalidBase64
        case invalidJSON
    }
    
    /// Decode a JWT token and extract the payload as a dictionary
    /// - Parameter jwt: The JWT token string
    /// - Returns: Dictionary containing the JWT payload claims
    static func decodePayload(_ jwt: String) throws -> [String: Any] {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else {
            throw JWTError.invalidFormat
        }
        
        var base64 = String(parts[1])
        
        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }
        
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JWTError.invalidBase64
        }
        
        return json
    }
    
    /// Extract the "sub" (subject) claim from a JWT token
    /// - Parameter jwt: The JWT token string
    /// - Returns: The subject claim value, or nil if not present
    static func extractSubject(_ jwt: String) -> String? {
        guard let payload = try? decodePayload(jwt) else {
            return nil
        }
        return payload["sub"] as? String
    }
    
    /// Extract a specific claim from a JWT token
    /// - Parameters:
    ///   - claim: The claim key to extract
    ///   - jwt: The JWT token string
    /// - Returns: The claim value, or nil if not present
    static func extractClaim(_ claim: String, from jwt: String) -> Any? {
        guard let payload = try? decodePayload(jwt) else {
            return nil
        }
        return payload[claim]
    }
    
    /// Decode a JWT token into a typed structure
    /// - Parameters:
    ///   - jwt: The JWT token string
    ///   - type: The Decodable type to decode into
    /// - Returns: The decoded payload
    static func decode<T: Decodable>(_ jwt: String, as type: T.Type) throws -> T {
        let payload = try decodePayload(jwt)
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    /// Check if a token is expired based on the "exp" claim
    /// - Parameter jwt: The JWT token string
    /// - Returns: True if expired or invalid, false if valid
    static func isExpired(_ jwt: String) -> Bool {
        guard let exp = extractClaim("exp", from: jwt) as? TimeInterval else {
            return true // Assume expired if no exp claim
        }
        return Date(timeIntervalSince1970: exp) < Date()
    }
}

// MARK: - Convenience Extensions

extension JWTUtils {
    
    /// Common JWT claims structure
    struct StandardClaims: Codable {
        let sub: String?      // Subject
        let iss: String?      // Issuer
        let aud: String?      // Audience
        let exp: TimeInterval? // Expiration
        let iat: TimeInterval? // Issued at
        let nbf: TimeInterval? // Not before
        let jti: String?      // JWT ID
    }
    
    /// Decode standard claims from a JWT
    static func decodeStandardClaims(_ jwt: String) -> StandardClaims? {
        try? decode(jwt, as: StandardClaims.self)
    }
}
