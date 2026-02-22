//
//  PlatformCredentialsSheets.swift
//  SocialMarketer
//
//  Credential input sheets for PlatformSettingsView
//

import SwiftUI

// MARK: - Generic Credentials Input Sheet

struct CredentialsInputSheet: View {
    let platform: PlatformInfo
    let onSave: (String, String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var clientID = ""
    @State private var clientSecret = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Setup \(platform.name)")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter your API credentials from the \(platform.name) Developer Portal.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(platform.clientIDLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter \(platform.clientIDLabel)", text: $clientID)
                        .textFieldStyle(.roundedBorder)
                }
                
                if platform.requiresSecret, let secretLabel = platform.clientSecretLabel {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(secretLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("Enter \(secretLabel)", text: $clientSecret)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave(clientID, platform.requiresSecret ? clientSecret : nil)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(clientID.isEmpty || (platform.requiresSecret && clientSecret.isEmpty))
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
        .onAppear {
            loadExistingCredentials()
        }
    }
    
    private func loadExistingCredentials() {
        if let creds = try? OAuthManager.shared.getAPICredentials(for: platform.id) {
            clientID = creds.clientID
            clientSecret = creds.clientSecret ?? ""
        }
    }
}

// MARK: - Twitter Credentials Input Sheet (OAuth 1.0a)

struct TwitterCredentialsInputSheet: View {
    let onSave: (String, String, String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var consumerKey = ""
    @State private var consumerSecret = ""
    @State private var accessToken = ""
    @State private var accessTokenSecret = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Setup X (Twitter)")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter your OAuth 1.0a credentials from the X Developer Portal.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key (Consumer Key)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter API Key", text: $consumerKey)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Secret (Consumer Secret)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Enter API Secret", text: $consumerSecret)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Access Token")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter Access Token", text: $accessToken)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Access Token Secret")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Enter Access Token Secret", text: $accessTokenSecret)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save & Connect") {
                    onSave(consumerKey, consumerSecret, accessToken, accessTokenSecret)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(consumerKey.isEmpty || consumerSecret.isEmpty || accessToken.isEmpty || accessTokenSecret.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420, height: 420)
        .onAppear {
            loadExistingCredentials()
        }
    }
    
    private func loadExistingCredentials() {
        if let creds = try? OAuthManager.shared.getTwitterOAuth1Credentials() {
            consumerKey = creds.consumerKey
            consumerSecret = creds.consumerSecret
            accessToken = creds.accessToken
            accessTokenSecret = creds.accessTokenSecret
        }
    }
}
