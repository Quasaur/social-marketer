//
//  PlatformConnectionRow.swift
//  SocialMarketer
//
//  Platform connection row component for PlatformSettingsView
//

import SwiftUI

struct PlatformConnectionRow: View {
    let platform: PlatformInfo
    let hasCredentials: Bool
    let state: ConnectionState
    let onSetup: () -> Void
    let onConnect: () async -> Void
    let onDisconnect: () -> Void
    var extraButton: AnyView? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            // Platform Icon
            Image(systemName: platform.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(platform.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Platform Name & Status
            VStack(alignment: .leading, spacing: 2) {
                Text(platform.name)
                    .font(.headline)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            // Actions
            if !hasCredentials {
                Button("Setup") { onSetup() }
                    .buttonStyle(.borderedProminent)
            } else {
                switch state {
                case .disconnected:
                    HStack(spacing: 8) {
                        Button("Edit") { onSetup() }
                            .buttonStyle(.bordered)
                        Button("Connect") { Task { await onConnect() } }
                            .buttonStyle(.borderedProminent)
                    }
                case .connecting:
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 16)
                case .connected:
                    HStack(spacing: 8) {
                        if let extra = extraButton {
                            extra
                        }
                        Button("Disconnect") { onDisconnect() }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private var statusText: String {
        if !hasCredentials { return "Setup required" }
        switch state {
        case .disconnected: return "Ready to connect"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        }
    }
    
    private var statusColor: Color {
        if !hasCredentials { return .orange }
        switch state {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        }
    }
}
