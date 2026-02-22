//
//  KeychainService.swift
//  SocialMarketer
//
//  Secure credential storage using macOS Keychain
//

import Foundation
import Security

/// Service for storing and retrieving platform credentials from Keychain
final class KeychainService: KeychainServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = KeychainService()
    
    // MARK: - Properties
    
    private let logger = Log.keychain
    private let serviceIdentifier = "com.wisdombook.SocialMarketer"
    
    // MARK: - Public Methods
    
    /// Save credentials for a platform
    func save(credentials: Data, for platform: String) throws {
        // Delete existing item first
        try? delete(for: platform)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: platform,
            kSecValueData as String: credentials,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            logger.error("Keychain save failed for \(platform): \(status)")
            throw KeychainError.saveFailed(status)
        }
        
        logger.info("Credentials saved for \(platform)")
    }
    
    /// Save Codable credentials
    func save<T: Codable>(_ credentials: T, for platform: String) throws {
        let data = try JSONEncoder().encode(credentials)
        try save(credentials: data, for: platform)
    }
    
    /// Retrieve credentials for a platform
    func retrieve(for platform: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: platform,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            logger.error("Keychain retrieve failed for \(platform): \(status)")
            throw KeychainError.retrieveFailed(status)
        }
        
        return data
    }
    
    /// Retrieve Codable credentials
    func retrieve<T: Codable>(_ type: T.Type, for platform: String) throws -> T {
        let data = try retrieve(for: platform)
        return try JSONDecoder().decode(type, from: data)
    }
    
    /// Delete credentials for a platform
    func delete(for platform: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: platform
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Keychain delete failed for \(platform): \(status)")
            throw KeychainError.deleteFailed(status)
        }
        
        logger.info("Credentials deleted for \(platform)")
    }
    
    /// Check if credentials exist for a platform
    func exists(for platform: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: platform,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Errors

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .retrieveFailed(let status):
            return "Failed to retrieve from Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        case .notFound:
            return "Credentials not found in Keychain"
        }
    }
}
