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
    @State private var credentialStatus: [String: Bool] = [:]
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedPlatform: PlatformInfo?
    
    
    // LinkedIn test state
    @State private var linkedinTesting = false
    @State private var showingSuccess = false
    
    // Twitter test state
    @State private var twitterTesting = false
    @State private var successMessage = ""
    
    // Facebook test state
    @State private var facebookTesting = false
    @State private var facebookPageName: String?
    
    // Instagram test state
    @State private var instagramTesting = false
    
    // Pinterest test state
    @State private var pinterestTesting = false
    
    // Tier expansion state
    @State private var tier2Expanded = false
    @State private var tier3Expanded = false
    
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
        let requiresSecret: Bool
        let clientIDLabel: String
        let clientSecretLabel: String?
    }
    
    private let platforms: [PlatformInfo] = [
        PlatformInfo(id: "twitter", name: "X (Twitter)", icon: "bird", color: .black,
                     requiresSecret: true, clientIDLabel: "Consumer Key", clientSecretLabel: "Consumer Secret"),
        PlatformInfo(id: "linkedin", name: "LinkedIn", icon: "person.2", color: .blue,
                     requiresSecret: true, clientIDLabel: "Client ID", clientSecretLabel: "Client Secret"),
        PlatformInfo(id: "facebook", name: "Facebook", icon: "person.3", color: .indigo,
                     requiresSecret: true, clientIDLabel: "App ID", clientSecretLabel: "App Secret"),
        PlatformInfo(id: "instagram", name: "Instagram", icon: "camera", color: .purple,
                     requiresSecret: true, clientIDLabel: "Instagram App ID", clientSecretLabel: "Instagram App Secret"),
        PlatformInfo(id: "pinterest", name: "Pinterest", icon: "pin", color: .red,
                     requiresSecret: true, clientIDLabel: "App ID", clientSecretLabel: "App Secret")
    ]
    
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
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") {}
        } message: {
            Text(successMessage)
        }
        .sheet(item: $selectedPlatform) { platform in
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
    }
    
    private func loadStates() {
        for platform in platforms {
            if platform.id == "twitter" {
                // Twitter uses OAuth 1.0a — check for 4-key credentials
                let hasTwitterCreds = oauthManager.hasTwitterOAuth1Credentials()
                credentialStatus["twitter"] = hasTwitterCreds
                connectionStatus["twitter"] = hasTwitterCreds ? .connected : .disconnected
            } else {
                // Other platforms use OAuth 2.0
                credentialStatus[platform.id] = oauthManager.hasAPICredentials(for: platform.id)
                if oauthManager.hasValidTokens(for: platform.id) {
                    connectionStatus[platform.id] = .connected
                } else {
                    connectionStatus[platform.id] = .disconnected
                }
            }
        }
    }
    
    private func extraButton(for platform: PlatformInfo) -> AnyView? {
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
        }
        return nil
    }
    
    private func showCredentialsSheet(for platform: PlatformInfo) {
        selectedPlatform = platform
    }
    
    private func saveCredentials(platform: PlatformInfo, clientID: String, clientSecret: String?) {
        do {
            let creds = OAuthManager.APICredentials(
                clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines),
                clientSecret: clientSecret?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try oauthManager.saveAPICredentials(creds, for: platform.id)
            credentialStatus[platform.id] = true
            CredentialBackupManager.shared.autoBackup()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func savePinterestCredentials(clientID: String, clientSecret: String, accessToken: String?) {
        do {
            // Save API credentials
            let creds = OAuthManager.APICredentials(
                clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines),
                clientSecret: clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try oauthManager.saveAPICredentials(creds, for: "pinterest")
            credentialStatus["pinterest"] = true
            CredentialBackupManager.shared.autoBackup()
            
            // If manual access token provided, save it directly
            if let token = accessToken, !token.isEmpty {
                let tokens = OAuthManager.OAuthTokens(
                    accessToken: token.trimmingCharacters(in: .whitespacesAndNewlines),
                    refreshToken: nil,
                    expiresAt: nil,
                    tokenType: "Bearer",
                    scope: "boards:read,pins:write",
                    idToken: nil
                )
                try oauthManager.saveTokens(tokens, for: "pinterest")
                connectionStatus["pinterest"] = .connected
                
                // Auto-discover boards for manual token users
                Task {
                    await discoverPinterestBoard(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func discoverPinterestBoard(token: String) async {
        do {
            // Fetch boards from Pinterest API
            let url = URL(string: "https://api.pinterest.com/v5/boards")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                errorMessage = "Failed to fetch Pinterest boards: \(errorBody)"
                showingError = true
                return
            }
            
            struct BoardsResponse: Decodable {
                struct Board: Decodable {
                    let id: String
                    let name: String
                }
                let items: [Board]
            }
            
            let boardsResponse = try JSONDecoder().decode(BoardsResponse.self, from: data)
            
            guard !boardsResponse.items.isEmpty else {
                errorMessage = "No Pinterest boards found. Create a board on Pinterest first."
                showingError = true
                return
            }
            
            // Prefer boards with "wisdom" first, then "book"
            let targetBoard = boardsResponse.items.first(where: {
                $0.name.localizedCaseInsensitiveContains("wisdom")
            }) ?? boardsResponse.items.first(where: {
                $0.name.localizedCaseInsensitiveContains("book")
            }) ?? boardsResponse.items.first!
            
            // Save board to Keychain
            struct PinterestCredentials: Codable {
                let boardID: String
                let boardName: String
            }
            
            let boardCreds = PinterestCredentials(boardID: targetBoard.id, boardName: targetBoard.name)
            try KeychainService.shared.save(boardCreds, for: "pinterest_board")
            
            // Show success
            successMessage = "Pinterest board configured: \(targetBoard.name)"
            showingSuccess = true
            
        } catch {
            errorMessage = "Board discovery failed: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func saveTwitterCredentials(consumerKey: String, consumerSecret: String, accessToken: String, accessTokenSecret: String) {
        do {
            let creds = OAuthManager.TwitterOAuth1Credentials(
                consumerKey: consumerKey.trimmingCharacters(in: .whitespacesAndNewlines),
                consumerSecret: consumerSecret.trimmingCharacters(in: .whitespacesAndNewlines),
                accessToken: accessToken.trimmingCharacters(in: .whitespacesAndNewlines),
                accessTokenSecret: accessTokenSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try oauthManager.saveTwitterOAuth1Credentials(creds)
            credentialStatus["twitter"] = true
            connectionStatus["twitter"] = .connected
            CredentialBackupManager.shared.autoBackup()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func connectPlatform(_ platform: PlatformInfo) async {
        // Twitter uses OAuth 1.0a — already connected when credentials are saved
        if platform.id == "twitter" {
            connectionStatus["twitter"] = oauthManager.hasTwitterOAuth1Credentials() ? .connected : .disconnected
            return
        }
        
        connectionStatus[platform.id] = .connecting
        
        do {
            if platform.id == "facebook" {
                // Facebook needs its own flow to also fetch Page Access Token
                let connector = FacebookConnector()
                try await connector.authenticate()
            } else if platform.id == "instagram" {
                // Instagram needs its own flow to discover Business Account ID
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
    
    private func disconnectPlatform(_ platform: PlatformInfo) {
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
    
    private func testTwitterPost() async {
        twitterTesting = true
        defer { twitterTesting = false }
        
        do {
            let connector = TwitterConnector()
            _ = await connector.isConfigured  // loads signer
            
            // Try image post if test graphic is available, otherwise text-only
            let caption = "📖 The Book of Wisdom — a curated collection of proverbs for the modern age.\n\n🔗 https://wisdombook.life\n\n#Wisdom #BookOfWisdom #Proverbs"
            
            if let imagePath = Bundle.main.path(forResource: "test_intro_graphic", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                let link = URL(string: "https://wisdombook.life")!
                let result = try await connector.post(image: image, caption: "", link: link)
                if result.success {
                    successMessage = "Image posted to X! 🎉\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            } else {
                let result = try await connector.postText(caption)
                if result.success {
                    successMessage = "Posted to X! 🎉\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            }
        } catch {
            errorMessage = "X post failed: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    // MARK: - LinkedIn Test Post
    
    private func testLinkedInPost() async {
        linkedinTesting = true
        defer { linkedinTesting = false }
        
        let introText = """
        Since the creation of Twitter in 2006 I have been posting the Wisdom that The Spirit of Christ has graciously given to me.

        In 2015 I published The Book of Tweets: Proverbs for the Modern Age on Amazon Kindle. In it I placed well over 600 proverbs, maxims and an adages.

        Since that time I have posted another 300 adages on 19 social media platforms in an effort to communicate with the world the critical importance of Biblical Wisdom to our mental health, fortune and survival.

        Now, in the latter days of my earthly journey, I am consolidating all of my work in a single Neo4j AURADB graph database which can be enjoyed by everyone free-of-charge through my new website The Book of Wisdom:

        https://www.wisdombook.life
        """
        
        do {
            let connector = LinkedInConnector()
            let tokens = try oauthManager.getTokens(for: "linkedin")
            connector.setAccessToken(tokens.accessToken)
            if let idToken = tokens.idToken {
                connector.setIdToken(idToken)
            } else {
                errorMessage = "No id_token found. Please Disconnect and Connect LinkedIn again to get new tokens with openid scope."
                showingError = true
                return
            }
            let result = try await connector.postText(introText)
            if result.success {
                successMessage = "Posted to LinkedIn! 🎉\n\(result.postURL?.absoluteString ?? "")"
                showingSuccess = true
            }
        } catch {
            errorMessage = "LinkedIn post failed: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    // MARK: - Facebook Test Post
    
    private func testFacebookPost() async {
        facebookTesting = true
        defer { facebookTesting = false }
        
        let introText = """
        Since the creation of Twitter in 2006 I have been posting the Wisdom that The Spirit of Christ has graciously given to me.

        In 2015 I published The Book of Tweets: Proverbs for the Modern Age on Amazon Kindle. In it I placed well over 600 proverbs, maxims and adages.

        Since that time I have posted another 300 adages on 19 social media platforms in an effort to communicate with the world the critical importance of Biblical Wisdom to our mental health, fortune and survival.

        Now, in the latter days of my earthly journey, I am consolidating all of my work in a single Neo4j AURADB graph database which can be enjoyed by everyone free-of-charge through my new website The Book of Wisdom:

        https://www.wisdombook.life
        """
        
        do {
            let connector = FacebookConnector()
            guard await connector.isConfigured else {
                errorMessage = "Facebook Page not configured. Try disconnecting and reconnecting Facebook."
                showingError = true
                return
            }
            
            // Post with intro graphic if available, otherwise text-only
            if let imagePath = Bundle.main.path(forResource: "test_intro_graphic", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                let link = URL(string: "https://www.wisdombook.life")!
                let result = try await connector.post(image: image, caption: introText, link: link)
                if result.success {
                    successMessage = "Intro posted to Facebook with graphic! 🎉\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            } else {
                let result = try await connector.postText(introText)
                if result.success {
                    successMessage = "Intro posted to Facebook! 🎉\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            }
        } catch {
            errorMessage = "Facebook post failed: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    // MARK: - Instagram Test Post
    
    private func testInstagramPost() async {
        instagramTesting = true
        defer { instagramTesting = false }
        
        do {
            let connector = InstagramConnector()
            guard await connector.isConfigured else {
                errorMessage = "Instagram not configured. Try disconnecting and reconnecting."
                showingError = true
                return
            }
            
            let introCaption = """
            📖 The Book of Wisdom — a curated collection of proverbs for the modern age.

            Since the creation of Twitter in 2006 I have been posting the Wisdom that The Spirit of Christ has graciously given to me.

            Now I am consolidating all of my work in a single graph database which can be enjoyed by everyone free-of-charge through my new website.

            #Wisdom #BookOfWisdom #Proverbs #BibleWisdom #WisdomBook
            """
            
            if let imagePath = Bundle.main.path(forResource: "test_intro_graphic", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                let link = URL(string: "https://www.wisdombook.life")!
                let result = try await connector.post(image: image, caption: introCaption, link: link)
                if result.success {
                    successMessage = "Posted to Instagram! 🎉\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            } else {
                errorMessage = "Could not load intro graphic for Instagram post."
                showingError = true
            }
        } catch {
            errorMessage = "Instagram post failed: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    // MARK: - Pinterest Test Post
    
    private func testPinterestPost() async {
        pinterestTesting = true
        defer { pinterestTesting = false }
        
        do {
            let connector = PinterestConnector()
            
            // Auto-discover board if not configured (for manual token users)
            if !(await connector.isConfigured) {
                // Fetch board using the manual access token
                if let tokens = try? OAuthManager.shared.getTokens(for: "pinterest") {
                    // Call the internal board discovery (need to make it accessible)
                    // For now, just show an error asking user to disconnect/reconnect
                    errorMessage = "Pinterest board not configured. Please Disconnect and Connect Pinterest again to auto-discover your boards."
                    showingError = true
                    return
                }
            }
            
            guard await connector.isConfigured else {
                errorMessage = "Pinterest not configured. Try disconnecting and reconnecting."
                showingError = true
                return
            }
            
            let caption = """
            Since the creation of Twitter in 2006 I have been posting the Wisdom that The Spirit of Christ has graciously given to me.

            In 2015 I published The Book of Tweets: Proverbs for the Modern Age on Amazon Kindle. In it I placed well over 600 proverbs, maxims and adages.

            Since that time I have posted another 300 adages on 19 social media platforms in an effort to communicate with the world the critical importance of Biblical Wisdom to our mental health, fortune and survival.

            Now, in the latter days of my earthly journey, I am consolidating all of my work in a single Neo4j AURADB graph database which can be enjoyed by everyone free-of-charge through my new website The Book of Wisdom:

            https://www.wisdombook.life
            """
            
            if let imagePath = Bundle.main.path(forResource: "test_intro_graphic", ofType: "png"),
               let image = NSImage(contentsOfFile: imagePath) {
                let link = URL(string: "https://www.wisdombook.life")!
                let result = try await connector.post(image: image, caption: caption, link: link)
                if result.success {
                    successMessage = "Pinned to Pinterest! 📌\n\(result.postURL?.absoluteString ?? "")"
                    showingSuccess = true
                }
            } else {
                errorMessage = "Could not load intro graphic for Pinterest pin."
                showingError = true
            }
        } catch {
            errorMessage = "Pinterest pin failed: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Platform Row

struct PlatformConnectionRow: View {
    let platform: PlatformSettingsView.PlatformInfo
    let hasCredentials: Bool
    let state: PlatformSettingsView.ConnectionState
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

// MARK: - Credentials Input Sheet

struct CredentialsInputSheet: View {
    let platform: PlatformSettingsView.PlatformInfo
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
        // Load existing API credentials if they exist
        if let creds = try? OAuthManager.shared.getAPICredentials(for: platform.id) {
            clientID = creds.clientID
            clientSecret = creds.clientSecret ?? ""
        }
    }
}

// MARK: - Twitter Credentials Input Sheet (OAuth 1.0a - 4 Keys)

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
        // Load existing Twitter OAuth 1.0a credentials if they exist
        if let creds = try? OAuthManager.shared.getTwitterOAuth1Credentials() {
            consumerKey = creds.consumerKey
            consumerSecret = creds.consumerSecret
            accessToken = creds.accessToken
            accessTokenSecret = creds.accessTokenSecret
        }
    }
}

#Preview {
    PlatformSettingsView()
}
