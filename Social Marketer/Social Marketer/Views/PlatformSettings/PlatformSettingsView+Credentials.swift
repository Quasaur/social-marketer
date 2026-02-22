//
//  PlatformSettingsView+Credentials.swift
//  SocialMarketer
//
//  Credential management for PlatformSettingsView
//

import SwiftUI

extension PlatformSettingsView {
    
    func saveCredentials(platform: PlatformInfo, clientID: String, clientSecret: String?) {
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
    
    func saveTwitterCredentials(consumerKey: String, consumerSecret: String, accessToken: String, accessTokenSecret: String) {
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
    
    func savePinterestCredentials(clientID: String, clientSecret: String, accessToken: String?) {
        do {
            let creds = OAuthManager.APICredentials(
                clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines),
                clientSecret: clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            try oauthManager.saveAPICredentials(creds, for: "pinterest")
            credentialStatus["pinterest"] = true
            CredentialBackupManager.shared.autoBackup()
            
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
                
                Task {
                    await discoverPinterestBoard(token: token.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    func discoverPinterestBoard(token: String) async {
        do {
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
            
            let targetBoard = boardsResponse.items.first(where: {
                $0.name.localizedCaseInsensitiveContains("wisdom")
            }) ?? boardsResponse.items.first(where: {
                $0.name.localizedCaseInsensitiveContains("book")
            }) ?? boardsResponse.items.first!
            
            struct PinterestCredentials: Codable {
                let boardID: String
                let boardName: String
            }
            
            let boardCreds = PinterestCredentials(boardID: targetBoard.id, boardName: targetBoard.name)
            try KeychainService.shared.save(boardCreds, for: "pinterest_board")
            
            successMessage = "Pinterest board configured: \(targetBoard.name)"
            showingSuccess = true
            
        } catch {
            errorMessage = "Board discovery failed: \(error.localizedDescription)"
            showingError = true
        }
    }
}
