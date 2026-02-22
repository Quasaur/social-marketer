//
//  PlatformSettingsView+Connection.swift
//  SocialMarketer
//
//  Connection management for PlatformSettingsView
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
            errorMessage = error.localizedDescription
            showingError = true
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
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    func extraButton(for platform: PlatformInfo) -> AnyView? {
        if platform.id == "twitter" && connectionStatus["twitter"] == .connected {
            return AnyView(
                Button(twitterTesting ? "Posting..." : "Test Tweet") {
                    Task { await testTwitterPost() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(twitterTesting)
            )
        } else if platform.id == "linkedin" && connectionStatus["linkedin"] == .connected {
            return AnyView(
                Button(linkedinTesting ? "Posting..." : "Test Post") {
                    Task { await testLinkedInPost() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(linkedinTesting)
            )
        } else if platform.id == "facebook" && connectionStatus["facebook"] == .connected {
            return AnyView(
                Button(facebookTesting ? "Posting..." : "Test Post") {
                    Task { await testFacebookPost() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(facebookTesting)
            )
        } else if platform.id == "instagram" && connectionStatus["instagram"] == .connected {
            return AnyView(
                Button(instagramTesting ? "Posting..." : "Test Post") {
                    Task { await testInstagramPost() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(instagramTesting)
            )
        } else if platform.id == "pinterest" && connectionStatus["pinterest"] == .connected {
            return AnyView(
                Button(pinterestTesting ? "Posting..." : "Test Pin") {
                    Task { await testPinterestPost() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(pinterestTesting)
            )
        } else if platform.id == "youtube" && connectionStatus["youtube"] == .connected {
            return AnyView(
                Button(youtubeTesting ? "Posting..." : "Test Post") {
                    Task { await testYouTubePost() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(youtubeTesting)
            )
        }
        return nil
    }
}
