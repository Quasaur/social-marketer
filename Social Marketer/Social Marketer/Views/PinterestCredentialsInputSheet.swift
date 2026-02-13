//  Pinterest Credentials Input Sheet
//  Specialized sheet for Pinterest with manual access token support

import SwiftUI

struct PinterestCredentialsInputSheet: View {
    let onSave: (String, String, String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var accessToken = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Setup Pinterest")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter your API credentials from the Pinterest Developer Portal.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("App ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Enter App ID", text: $clientID)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("App Secret")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("Enter App Secret", text: $clientSecret)
                        .textFieldStyle(.roundedBorder)
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Access Token (Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("If you have a manual access token from Pinterest, paste it here. Otherwise, leave blank and use OAuth.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Paste Access Token", text: $accessToken)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSave(clientID, clientSecret, accessToken.isEmpty ? nil : accessToken)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(clientID.isEmpty || clientSecret.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 450, height: 420)
        .onAppear {
            loadExistingCredentials()
        }
    }
    
    private func loadExistingCredentials() {
        // Load existing API credentials if they exist
        if let creds = try? OAuthManager.shared.getAPICredentials(for: "pinterest") {
            clientID = creds.clientID
            clientSecret = creds.clientSecret ?? ""
        }
        
        // Load existing access token if it exists
        if let tokens = try? OAuthManager.shared.getTokens(for: "pinterest") {
            accessToken = tokens.accessToken
        }
    }
}
