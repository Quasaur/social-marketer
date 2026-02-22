//
//  PlatformSettingsView.swift
//  SocialMarketer
//
//  UI for connecting and managing social media platform accounts
//  Refactored to use TestPostManager for unified test post handling
//

import SwiftUI

struct PlatformSettingsView: View {
    @StateObject var oauthManager = OAuthManager.shared
    @StateObject var testManager = TestPostManager.shared
    @State var connectionStatus: [String: ConnectionState] = [:]
    @State var credentialStatus: [String: Bool] = [:]
    @State var selectedPlatform: PlatformInfo?
    
    // Legacy test states (for Instagram, Pinterest, YouTube - migrate later)
    @State var instagramTesting = false
    @State var pinterestTesting = false
    @State var youtubeTesting = false
    
    // Legacy alert states (for Instagram, Pinterest, YouTube - migrate later)
    @State var showingError = false
    @State var errorMessage = ""
    @State var showingSuccess = false
    @State var successMessage = ""
    
    // Tier expansion state
    @State var tier2Expanded = false
    @State var tier3Expanded = false
    
    let platforms = PlatformInfo.allPlatforms
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Social Media Platforms")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
            
            Text("Connect your social media accounts for automated posting.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
            Divider()
            
            // Platform List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(platforms) { platform in
                        PlatformConnectionRow(
                            platform: platform,
                            hasCredentials: credentialStatus[platform.id] ?? false,
                            state: connectionStatus[platform.id] ?? .disconnected,
                            onSetup: { showCredentialsSheet(for: platform) },
                            onConnect: { await connectPlatform(platform) },
                            onDisconnect: { disconnectPlatform(platform) },
                            extraButton: extraButton(for: platform)
                        )
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Tier 2 — API Available
            ScrollView {
                VStack(spacing: 16) {
                    DisclosureGroup(isExpanded: $tier2Expanded) {
                        ForEach(PlatformTier.apiAvailable, id: \.name) { item in
                            FuturePlatformRow(name: item.name, icon: item.icon, note: item.note)
                        }
                    } label: {
                        TierHeader(title: "API Available", icon: "antenna.radiowaves.left.and.right", color: .blue, count: nil, total: PlatformTier.apiAvailable.count)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Tier 3 — The Rest
                    DisclosureGroup(isExpanded: $tier3Expanded) {
                        ForEach(PlatformTier.theRest, id: \.name) { item in
                            FuturePlatformRow(name: item.name, icon: item.icon, note: item.note)
                        }
                    } label: {
                        TierHeader(title: "The Rest", icon: "ellipsis.circle", color: .secondary, count: nil, total: PlatformTier.theRest.count)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            loadStates()
        }
        // Unified alert handling via TestPostManager
        .testPostAlerts(manager: testManager)
        .sheet(item: $selectedPlatform) { platform in
            sheetContent(for: platform)
        }
    }
    
    @ViewBuilder
    private func sheetContent(for platform: PlatformInfo) -> some View {
        if platform.id == "twitter" {
            TwitterCredentialsInputSheet(
                onSave: { consumerKey, consumerSecret, accessToken, accessTokenSecret in
                    saveTwitterCredentials(
                        consumerKey: consumerKey,
                        consumerSecret: consumerSecret,
                        accessToken: accessToken,
                        accessTokenSecret: accessTokenSecret
                    )
                }
            )
        } else if platform.id == "pinterest" {
            PinterestCredentialsInputSheet(
                onSave: { clientID, clientSecret, accessToken in
                    savePinterestCredentials(clientID: clientID, clientSecret: clientSecret, accessToken: accessToken)
                }
            )
        } else {
            CredentialsInputSheet(
                platform: platform,
                onSave: { clientID, clientSecret in
                    saveCredentials(platform: platform, clientID: clientID, clientSecret: clientSecret)
                }
            )
        }
    }
    
    private func showCredentialsSheet(for platform: PlatformInfo) {
        selectedPlatform = platform
    }
}

#Preview {
    PlatformSettingsView()
}
