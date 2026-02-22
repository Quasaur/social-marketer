//
//  PlatformSettingsView+Connection.swift
//  SocialMarketer
//
//  Connection management for PlatformSettingsView
//  Refactored to use TestPostManager for test post buttons
//

import SwiftUI

extension PlatformSettingsView {
    
    func loadStates() {
        for platform in platforms {
            if platform.id == "twitter" {
                let hasTwitterCreds = oauthManager.hasTwitterOAuth1Credentials()
                credentialStatus["twitter"] = hasTwitterCreds
                connectionStatus["twitter"] = hasTwitterCreds ? .connected : .disconnected
            } else {
                credentialStatus[platform.id] = oauthManager.hasAPICredentials(for: platform.id)
                if oauthManager.hasValidTokens(for: platform.id) {
                    connectionStatus[platform.id] = .connected
                } else {
                    connectionStatus[platform.id] = .disconnected
                }
            }
        }
    }
    
    func connectPlatform(_ platform: PlatformInfo) async {
        if platform.id == "twitter" {
            connectionStatus["twitter"] = oauthManager.hasTwitterOAuth1Credentials() ? .connected : .disconnected
            return
        }
        
        connectionStatus[platform.id] = .connecting
        
        do {
            if platform.id == "facebook" {
                let connector = FacebookConnector()
                try await connector.authenticate()
            } else if platform.id == "instagram" {
                let connector = InstagramConnector()
                try await connector.authenticate()
            } else {
                let config = try oauthManager.getConfig(for: platform.id)
                let tokens = try await oauthManager.authenticate(platform: platform.id, config: config)
                try oauthManager.saveTokens(tokens, for: platform.id)
            }
            
            connectionStatus[platform.id] = .connected
        } catch {
            connectionStatus[platform.id] = .disconnected
            // Use TestPostManager for consistent error handling
            TestPostManager.shared.showError(error.localizedDescription)
        }
    }
    
    func disconnectPlatform(_ platform: PlatformInfo) {
        do {
            if platform.id == "twitter" {
                try oauthManager.removeTwitterOAuth1Credentials()
                credentialStatus["twitter"] = false
            } else {
                try oauthManager.removeTokens(for: platform.id)
            }
            connectionStatus[platform.id] = .disconnected
        } catch {
            TestPostManager.shared.showError(error.localizedDescription)
        }
    }
    
    /// Returns test button for connected platforms using TestPostManager
    func extraButton(for platform: PlatformInfo) -> AnyView? {
        guard connectionStatus[platform.id] == .connected else { return nil }
        
        switch platform.id {
        case "twitter":
            return AnyView(TestPostButton(
                platform: "twitter",
                label: "Test Tweet",
                manager: testManager
            ) {
                await testManager.testTwitterPost()
            })
            
        case "linkedin":
            return AnyView(TestPostButton(
                platform: "linkedin",
                label: "Test Post",
                manager: testManager
            ) {
                await testManager.testLinkedInPost(oauthManager: oauthManager)
            })
            
        case "facebook":
            return AnyView(TestPostButton(
                platform: "facebook",
                label: "Test Post",
                manager: testManager
            ) {
                await testManager.testFacebookPost()
            })
            
        case "instagram":
            return AnyView(TestPostButton(
                platform: "instagram",
                label: "Test Post",
                manager: testManager
            ) {
                await testInstagramPost()
            })
            
        case "pinterest":
            return AnyView(TestPostButton(
                platform: "pinterest",
                label: "Test Pin",
                manager: testManager
            ) {
                await testPinterestPost()
            })
            
        case "youtube":
            return AnyView(TestPostButton(
                platform: "youtube",
                label: "Test Post",
                manager: testManager
            ) {
                await testYouTubePost()
            })
            
        default:
            return nil
        }
    }
}

