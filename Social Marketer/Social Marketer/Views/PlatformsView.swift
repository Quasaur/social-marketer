//
//  PlatformsView.swift
//  SocialMarketer
//
//  View for configuring platform connections and credentials
//

import SwiftUI

struct PlatformsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>
    
    @State private var selectedPlatform: Platform?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Platform Configuration")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            Text("Connect your social media accounts to enable automated posting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            // Platform List
            List(platforms) { platform in
                PlatformConfigRow(platform: platform)
            }
            .listStyle(.inset)
        }
        .padding(.top)
    }
}

struct PlatformConfigRow: View {
    @ObservedObject var platform: Platform
    @State private var isConfiguring = false
    
    private var hasCredentials: Bool {
        KeychainService.shared.exists(for: platform.name ?? "")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Platform icon
            Image(systemName: iconForPlatform(platform.name ?? ""))
                .font(.title2)
                .foregroundStyle(hasCredentials ? .green : .secondary)
                .frame(width: 40)
            
            // Platform info
            VStack(alignment: .leading, spacing: 4) {
                Text(platform.name ?? "Unknown")
                    .font(.headline)
                
                if hasCredentials {
                    Text("Connected")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("Not configured")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Enable toggle
            Toggle("Enabled", isOn: Binding(
                get: { platform.isEnabled },
                set: { newValue in
                    platform.isEnabled = newValue
                    PersistenceController.shared.save()
                }
            ))
            .labelsHidden()
            .disabled(!hasCredentials)
            
            // Configure button
            Button(hasCredentials ? "Reconfigure" : "Connect") {
                isConfiguring = true
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $isConfiguring) {
            PlatformCredentialSheet(platform: platform)
        }
    }
    
    private func iconForPlatform(_ name: String) -> String {
        switch name {
        case "X (Twitter)": return "xmark.circle"
        case "Instagram": return "camera"
        case "LinkedIn": return "briefcase"
        case "YouTube": return "play.rectangle"
        case "Substack": return "envelope"
        default: return "globe"
        }
    }
}

struct PlatformCredentialSheet: View {
    let platform: Platform
    @Environment(\.dismiss) private var dismiss
    
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var accessToken = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Configure \(platform.name ?? "Platform")")
                .font(.headline)
            
            Text("Enter your API credentials for \(platform.name ?? "this platform"). These are stored securely in your Mac's Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Form {
                SecureField("API Key", text: $apiKey)
                SecureField("API Secret", text: $apiSecret)
                SecureField("Access Token", text: $accessToken)
            }
            .formStyle(.grouped)
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save") {
                    saveCredentials()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.isEmpty || accessToken.isEmpty || isSaving)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func saveCredentials() {
        isSaving = true
        errorMessage = nil
        
        // Create credentials struct
        let credentials: [String: String] = [
            "apiKey": apiKey,
            "apiSecret": apiSecret,
            "accessToken": accessToken
        ]
        
        do {
            try KeychainService.shared.save(credentials, for: platform.name ?? "")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
}

#Preview {
    PlatformsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
