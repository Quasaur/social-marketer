//
//  PlatformSettingsModels.swift
//  SocialMarketer
//
//  Shared models for PlatformSettingsView
//

import SwiftUI

// MARK: - Connection State

enum ConnectionState {
    case disconnected
    case connecting
    case connected
}

// MARK: - Platform Info

struct PlatformInfo: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let requiresSecret: Bool
    let clientIDLabel: String
    let clientSecretLabel: String?
}

// MARK: - Platform List

extension PlatformInfo {
    static let allPlatforms: [PlatformInfo] = [
        PlatformInfo(id: "twitter", name: "X (Twitter)", icon: "bird", color: .black,
                     requiresSecret: true, clientIDLabel: "Consumer Key", clientSecretLabel: "Consumer Secret"),
        PlatformInfo(id: "linkedin", name: "LinkedIn", icon: "person.2", color: .blue,
                     requiresSecret: true, clientIDLabel: "Client ID", clientSecretLabel: "Client Secret"),
        PlatformInfo(id: "facebook", name: "Facebook", icon: "person.3", color: .indigo,
                     requiresSecret: true, clientIDLabel: "App ID", clientSecretLabel: "App Secret"),
        PlatformInfo(id: "instagram", name: "Instagram", icon: "camera", color: .purple,
                     requiresSecret: true, clientIDLabel: "Instagram App ID", clientSecretLabel: "Instagram App Secret"),
        PlatformInfo(id: "pinterest", name: "Pinterest", icon: "pin", color: .red,
                     requiresSecret: true, clientIDLabel: "App ID", clientSecretLabel: "App Secret"),
        PlatformInfo(id: "youtube", name: "YouTube", icon: "play.rectangle", color: .red,
                     requiresSecret: true, clientIDLabel: "Client ID", clientSecretLabel: "Client Secret")
    ]
}
