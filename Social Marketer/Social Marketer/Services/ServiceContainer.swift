//
//  ServiceContainer.swift
//  SocialMarketer
//
//  Dependency injection container for managing service lifecycles
//

import Foundation
import CoreData
import SwiftUI

/// Dependency injection container for Social Marketer services
///
/// Usage:
/// ```swift
/// // In app initialization
/// let container = ServiceContainer.shared
/// container.register(PersistenceServiceProtocol.self, instance: PersistenceController.shared)
///
/// // In views/view models
/// @Environment(\.persistence) var persistence
/// ```
final class ServiceContainer {
    
    static let shared = ServiceContainer()
    
    private var registry: [String: Any] = [:]
    
    private init() {
        registerDefaultServices()
    }
    
    // MARK: - Registration
    
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        registry[key] = instance
    }
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        registry[key] = factory
    }
    
    // MARK: - Resolution
    
    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        if let instance = registry[key] as? T {
            return instance
        }
        
        if let factory = registry[key] as? () -> T {
            return factory()
        }
        
        return nil
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        guard let service = resolve(type) else {
            fatalError("Service not registered: \(type)")
        }
        return service
    }
    
    // MARK: - Default Registration
    
    private func registerDefaultServices() {
        // Persistence (keep as singleton for Core Data)
        register(PersistenceServiceProtocol.self, instance: PersistenceController.shared)
        
        // Keychain
        register(KeychainServiceProtocol.self, instance: KeychainService.shared)
        
        // OAuth
        register(OAuthServiceProtocol.self, instance: OAuthManager.shared)
        
        // Error Logging
        register(ErrorLogServiceProtocol.self, instance: ErrorLog.shared)
        
        // Social Effects
        register(SocialEffectsServiceProtocol.self, instance: SocialEffectsService.shared)
        
        // Content Service
        register(ContentServiceProtocol.self, instance: ContentService.shared)
    }
    
    // MARK: - Testing Support
    
    func reset() {
        registry.removeAll()
        registerDefaultServices()
    }
    
    func unregister<T>(_ type: T.Type) {
        let key = String(describing: type)
        registry.removeValue(forKey: key)
    }
}

// MARK: - SwiftUI Environment

private struct PersistenceServiceKey: EnvironmentKey {
    static let defaultValue: PersistenceServiceProtocol = PersistenceController.shared
}

private struct KeychainServiceKey: EnvironmentKey {
    static let defaultValue: KeychainServiceProtocol = KeychainService.shared
}

private struct OAuthServiceKey: EnvironmentKey {
    static let defaultValue: OAuthServiceProtocol = OAuthManager.shared
}

private struct ErrorLogServiceKey: EnvironmentKey {
    static let defaultValue: ErrorLogServiceProtocol = ErrorLog.shared
}

private struct SocialEffectsServiceKey: EnvironmentKey {
    static let defaultValue: SocialEffectsServiceProtocol = SocialEffectsService.shared
}

private struct ContentServiceKey: EnvironmentKey {
    static let defaultValue: ContentServiceProtocol = ContentService.shared
}

extension EnvironmentValues {
    var persistence: PersistenceServiceProtocol {
        get { self[PersistenceServiceKey.self] }
        set { self[PersistenceServiceKey.self] = newValue }
    }
    
    var keychain: KeychainServiceProtocol {
        get { self[KeychainServiceKey.self] }
        set { self[KeychainServiceKey.self] = newValue }
    }
    
    var oauth: OAuthServiceProtocol {
        get { self[OAuthServiceKey.self] }
        set { self[OAuthServiceKey.self] = newValue }
    }
    
    var errorLog: ErrorLogServiceProtocol {
        get { self[ErrorLogServiceKey.self] }
        set { self[ErrorLogServiceKey.self] = newValue }
    }
    
    var socialEffects: SocialEffectsServiceProtocol {
        get { self[SocialEffectsServiceKey.self] }
        set { self[SocialEffectsServiceKey.self] = newValue }
    }
    
    var contentService: ContentServiceProtocol {
        get { self[ContentServiceKey.self] }
        set { self[ContentServiceKey.self] = newValue }
    }
}

// MARK: - View Modifier for Injection

struct ServiceInjectionModifier: ViewModifier {
    let container: ServiceContainer
    
    func body(content: Content) -> some View {
        content
            .environment(\.persistence, container.resolve(PersistenceServiceProtocol.self)!)
            .environment(\.keychain, container.resolve(KeychainServiceProtocol.self)!)
            .environment(\.oauth, container.resolve(OAuthServiceProtocol.self)!)
            .environment(\.errorLog, container.resolve(ErrorLogServiceProtocol.self)!)
            .environment(\.socialEffects, container.resolve(SocialEffectsServiceProtocol.self)!)
            .environment(\.contentService, container.resolve(ContentServiceProtocol.self)!)
    }
}

extension View {
    func withServices(from container: ServiceContainer = .shared) -> some View {
        modifier(ServiceInjectionModifier(container: container))
    }
}
