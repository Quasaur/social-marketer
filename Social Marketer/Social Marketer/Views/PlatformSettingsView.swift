//
//  PlatformSettingsView.swift
//  SocialMarketer
//
//  UI for connecting and managing social media platform accounts
//

import SwiftUI

struct PlatformSettingsView: View {
    @StateObject private var oauthManager = OAuthManager.shared
    @State private var connectionStatus: [String: ConnectionState] = [:]
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    struct PlatformInfo: Identifiable {
        let id: String
        let name: String
        let icon: String
        let color: Color
        let config: OAuthManager.OAuthConfig?
    }
    
    private let platforms: [PlatformInfo] = [
        PlatformInfo(id: "twitter", name: "X (Twitter)", icon: "bird", color: .black, config: .twitter),
        PlatformInfo(id: "instagram", name: "Instagram", icon: "camera", color: .purple, config: nil), // Uses Facebook auth
        PlatformInfo(id: "linkedin", name: "LinkedIn", icon: "person.2", color: .blue, config: .linkedin),
        PlatformInfo(id: "facebook", name: "Facebook", icon: "person.3", color: .indigo, config: .facebook),
        PlatformInfo(id: "pinterest", name: "Pinterest", icon: "pin", color: .red, config: .pinterest)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Connected Platforms")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
            
            Text("Connect your social media accounts to enable automated posting.")
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
                            state: connectionStatus[platform.id] ?? .disconnected,
                            onConnect: { await connectPlatform(platform) },
                            onDisconnect: { disconnectPlatform(platform) }
                        )
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            
            Spacer()
            
            // Info Footer
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Some platforms share authentication. Connecting Facebook also enables Instagram.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
        }
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            loadConnectionStates()
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadConnectionStates() {
        for platform in platforms {
            if oauthManager.hasValidTokens(for: platform.id) {
                connectionStatus[platform.id] = .connected
            } else {
                connectionStatus[platform.id] = .disconnected
            }
        }
        
        // Instagram uses Facebook tokens
        if connectionStatus["facebook"] == .connected {
            connectionStatus["instagram"] = .connected
        }
    }
    
    private func connectPlatform(_ platform: PlatformInfo) async {
        // Instagram uses Facebook auth
        let targetPlatform = platform.id == "instagram" ? platforms.first { $0.id == "facebook" }! : platform
        
        guard let config = targetPlatform.config else {
            errorMessage = "Configuration not available for \(platform.name)"
            showingError = true
            return
        }
        
        connectionStatus[platform.id] = .connecting
        
        do {
            let tokens = try await oauthManager.authenticate(platform: targetPlatform.id, config: config)
            try oauthManager.saveTokens(tokens, for: targetPlatform.id)
            
            connectionStatus[platform.id] = .connected
            
            // If Facebook connected, Instagram is also connected
            if targetPlatform.id == "facebook" {
                connectionStatus["instagram"] = .connected
            }
        } catch {
            connectionStatus[platform.id] = .disconnected
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func disconnectPlatform(_ platform: PlatformInfo) {
        do {
            try oauthManager.removeTokens(for: platform.id)
            connectionStatus[platform.id] = .disconnected
            
            // If Facebook disconnected, Instagram too
            if platform.id == "facebook" {
                connectionStatus["instagram"] = .disconnected
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Platform Row

struct PlatformConnectionRow: View {
    let platform: PlatformSettingsView.PlatformInfo
    let state: PlatformSettingsView.ConnectionState
    let onConnect: () async -> Void
    let onDisconnect: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Platform Icon
            Image(systemName: platform.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(platform.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Platform Name
            VStack(alignment: .leading, spacing: 2) {
                Text(platform.name)
                    .font(.headline)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            // Action Button
            switch state {
            case .disconnected:
                Button("Connect") {
                    Task { await onConnect() }
                }
                .buttonStyle(.borderedProminent)
                
            case .connecting:
                ProgressView()
                    .controlSize(.small)
                    .padding(.horizontal, 16)
                
            case .connected:
                Button("Disconnect") {
                    onDisconnect()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private var statusText: String {
        switch state {
        case .disconnected: return "Not connected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        }
    }
}

#Preview {
    PlatformSettingsView()
}
