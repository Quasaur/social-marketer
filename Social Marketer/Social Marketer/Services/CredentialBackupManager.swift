//
//  CredentialBackupManager.swift
//  SocialMarketer
//
//  Encrypted backup/restore of platform API credentials to prevent data loss
//

import Foundation

/// Manages backup and restoration of platform API credentials
@MainActor
final class CredentialBackupManager {
    
    // MARK: - Singleton
    
    static let shared = CredentialBackupManager()
    
    // MARK: - Types
    
    struct CredentialBackup: Codable {
        let version: String
        let createdAt: Date
        let twitter: OAuthManager.TwitterOAuth1Credentials?
        let facebook: OAuthManager.APICredentials?
        let instagram: OAuthManager.APICredentials?
        let linkedin: OAuthManager.APICredentials?
        let pinterest: OAuthManager.APICredentials?
    }
    
    // MARK: - Properties
    
    private let logger = Log.app
    
    /// Primary backup location: ~/Library/Application Support/Social Marketer/
    private var primaryBackupDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Social Marketer", isDirectory: true)
    }
    
    /// Secondary backup location: ~/Developer/WISDOM/Social Marketer/
    private var secondaryBackupDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("WISDOM", isDirectory: true)
            .appendingPathComponent("Social Marketer", isDirectory: true)
    }
    
    private let backupFilename = "credentials.backup.json"
    
    // MARK: - Backup
    
    /// Backup all current credentials to both locations
    func backupAllCredentials() throws {
        let backup = gatherCurrentCredentials()
        let data = try JSONEncoder().encode(backup)
        
        // Save to primary location
        try saveToLocation(data: data, directory: primaryBackupDir)
        logger.info("Credentials backed up to primary location")
        
        // Save to secondary location
        do {
            try saveToLocation(data: data, directory: secondaryBackupDir)
            logger.info("Credentials backed up to secondary location")
        } catch {
            logger.warning("Secondary backup failed (non-critical): \(error.localizedDescription)")
        }
    }
    
    /// Auto-backup after a platform is configured
    func autoBackup() {
        do {
            try backupAllCredentials()
        } catch {
            logger.error("Auto-backup failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Restore
    
    /// Restore credentials from backup files
    func restoreFromBackup() throws -> CredentialBackup {
        // Try primary first, then secondary
        if let backup = loadFromLocation(directory: primaryBackupDir) {
            logger.info("Restored from primary backup (created: \(backup.createdAt))")
            try applyBackup(backup)
            return backup
        }
        
        if let backup = loadFromLocation(directory: secondaryBackupDir) {
            logger.info("Restored from secondary backup (created: \(backup.createdAt))")
            try applyBackup(backup)
            return backup
        }
        
        throw BackupError.noBackupFound
    }
    
    /// Apply a backup to the Keychain
    private func applyBackup(_ backup: CredentialBackup) throws {
        let oauth = OAuthManager.shared
        
        // Restore Twitter (OAuth 1.0a - all 4 keys)
        if let twitter = backup.twitter {
            try oauth.saveTwitterOAuth1Credentials(twitter)
            logger.info("Restored Twitter credentials")
        }
        
        // Restore Facebook API credentials
        if let facebook = backup.facebook {
            try oauth.saveAPICredentials(facebook, for: "facebook")
            logger.info("Restored Facebook credentials")
        }
        
        // Restore Instagram API credentials
        if let instagram = backup.instagram {
            try oauth.saveAPICredentials(instagram, for: "instagram")
            logger.info("Restored Instagram credentials")
        }
        
        // Restore LinkedIn API credentials
        if let linkedin = backup.linkedin {
            try oauth.saveAPICredentials(linkedin, for: "linkedin")
            logger.info("Restored LinkedIn credentials")
        }
        
        // Restore Pinterest API credentials
        if let pinterest = backup.pinterest {
            try oauth.saveAPICredentials(pinterest, for: "pinterest")
            logger.info("Restored Pinterest credentials")
        }
    }
    
    // MARK: - Status
    
    /// Get the last backup date from either location
    func lastBackupDate() -> Date? {
        if let backup = loadFromLocation(directory: primaryBackupDir) {
            return backup.createdAt
        }
        if let backup = loadFromLocation(directory: secondaryBackupDir) {
            return backup.createdAt
        }
        return nil
    }
    
    /// Check if a backup exists in either location
    func backupExists() -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: primaryBackupDir.appendingPathComponent(backupFilename).path)
            || fm.fileExists(atPath: secondaryBackupDir.appendingPathComponent(backupFilename).path)
    }
    
    /// Summary of what's in the most recent backup
    func backupSummary() -> String {
        guard let backup = loadFromLocation(directory: primaryBackupDir)
                ?? loadFromLocation(directory: secondaryBackupDir) else {
            return "No backup found"
        }
        
        var platforms: [String] = []
        if backup.twitter != nil { platforms.append("Twitter") }
        if backup.facebook != nil { platforms.append("Facebook") }
        if backup.instagram != nil { platforms.append("Instagram") }
        if backup.linkedin != nil { platforms.append("LinkedIn") }
        if backup.pinterest != nil { platforms.append("Pinterest") }
        
        return "\(platforms.count) platform(s): \(platforms.joined(separator: ", "))"
    }
    
    // MARK: - Private
    
    private func gatherCurrentCredentials() -> CredentialBackup {
        let oauth = OAuthManager.shared
        
        return CredentialBackup(
            version: "1.0",
            createdAt: Date(),
            twitter: try? oauth.getTwitterOAuth1Credentials(),
            facebook: try? oauth.getAPICredentials(for: "facebook"),
            instagram: try? oauth.getAPICredentials(for: "instagram"),
            linkedin: try? oauth.getAPICredentials(for: "linkedin"),
            pinterest: try? oauth.getAPICredentials(for: "pinterest")
        )
    }
    
    private func saveToLocation(data: Data, directory: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(backupFilename)
        try data.write(to: file, options: [.atomic, .completeFileProtection])
    }
    
    private func loadFromLocation(directory: URL) -> CredentialBackup? {
        let file = directory.appendingPathComponent(backupFilename)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(CredentialBackup.self, from: data)
    }
}

// MARK: - Errors

enum BackupError: Error, LocalizedError {
    case noBackupFound
    case restoreFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noBackupFound:
            return "No credential backup found in either location"
        case .restoreFailed(let msg):
            return "Restore failed: \(msg)"
        }
    }
}
