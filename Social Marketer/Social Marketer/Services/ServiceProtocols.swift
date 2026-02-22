//
//  ServiceProtocols.swift
//  SocialMarketer
//
//  Protocols for dependency injection
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Persistence Protocol

protocol PersistenceServiceProtocol {
    var viewContext: NSManagedObjectContext { get }
    func newBackgroundContext() -> NSManagedObjectContext
    func save()
    func save(context: NSManagedObjectContext)
}

// MARK: - Keychain Protocol

protocol KeychainServiceProtocol {
    func save<T: Codable>(_ credentials: T, for key: String) throws
    func retrieve<T: Codable>(_ type: T.Type, for key: String) throws -> T
    func delete(for key: String) throws
    func exists(for key: String) -> Bool
}

// MARK: - OAuth Protocol

protocol OAuthServiceProtocol {
    func getConfig(for platform: String) throws -> OAuthManager.OAuthConfig
    func authenticate(platform: String, config: OAuthManager.OAuthConfig) async throws -> OAuthManager.OAuthTokens
    func saveTokens(_ tokens: OAuthManager.OAuthTokens, for platform: String) throws
    func getTokens(for platform: String) throws -> OAuthManager.OAuthTokens
    func removeTokens(for platform: String) throws
    func hasValidTokens(for platform: String) -> Bool
    func hasAPICredentials(for platform: String) -> Bool
}

// MARK: - Logging Protocol

protocol LoggingServiceProtocol {
    func log(category: String, message: String, detail: String?)
}

// MARK: - Error Logging Protocol

protocol ErrorLogServiceProtocol {
    func log(category: String, message: String, detail: String?)
    func clear()
    var entries: [ErrorEntry] { get }
}

// MARK: - Social Effects Protocol

protocol SocialEffectsServiceProtocol {
    func ensureServerRunning() async -> Bool
    func generateVideo(from item: RSSItem) async throws -> String
    func shutdown() async
}

// MARK: - Content Service Protocol

protocol ContentServiceProtocol {
    func refreshContent() async throws -> Int
    func fetchDaily() async throws -> WisdomEntry?
    func getNextEntryForPosting() async -> CachedWisdomEntry?
    func markAsPosted(_ entry: CachedWisdomEntry) async
}

// MARK: - Test Post Service Protocol

protocol TestPostServiceProtocol {
    var isTesting: Bool { get }
    var showingError: Bool { get set }
    var showingSuccess: Bool { get set }
    var message: String { get set }
    
    func isTesting(platform: String) -> Bool
    func testTwitterPost() async
    func testLinkedInPost(oauthManager: OAuthManager) async
    func testFacebookPost() async
    func showError(_ message: String)
}

// MARK: - Platform Connector Factory Protocol

protocol PlatformConnectorFactoryProtocol {
    func makeConnector(for platform: PlatformType) -> PlatformConnector?
    func makeVideoConnector(for platform: PlatformType) -> VideoPlatformConnector?
}

// MARK: - Post Scheduler Protocol

protocol PostSchedulerProtocol {
    func schedulePost(_ post: Post, for platforms: [PlatformType]) async throws
    func cancelScheduledPost(_ post: Post)
    func getPendingPosts() async -> [Post]
}
