//
//  PinterestConnector.swift
//  SocialMarketer
//
//  Created by Automation on 2026-02-16.
//

import Foundation
import AppKit

// MARK: - Pinterest Connector

struct PinterestCredentials: Codable {
    let boardID: String
    let boardName: String
}

final class PinterestConnector: PlatformConnector {
    let platformName = "Pinterest"
    private let logger = Log.pinterest
    private var accessToken: String?
    private var boardID: String?
    private var boardName: String?
    
    var isConfigured: Bool {
        get async {
            // Load cached credentials
            if let cached = try? KeychainService.shared.retrieve(PinterestCredentials.self, for: "pinterest_board") {
                boardID = cached.boardID
                boardName = cached.boardName
            }
            
            do {
                let tokens = try OAuthManager.shared.getTokens(for: "pinterest")
                accessToken = tokens.accessToken
                return boardID != nil
            } catch {
                return false
            }
        }
    }
    
    func authenticate() async throws {
        let config = try OAuthManager.shared.getConfig(for: "pinterest")
        let tokens = try await OAuthManager.shared.authenticate(
            platform: "pinterest",
            config: config
        )
        try OAuthManager.shared.saveTokens(tokens, for: "pinterest")
        accessToken = tokens.accessToken
        
        // Auto-discover the user's first board
        try await fetchFirstBoard(token: tokens.accessToken)
    }
    
    func post(image: NSImage, caption: String, link: URL) async throws -> PostResult {
        guard let token = accessToken, let board = boardID else {
            throw PlatformError.notConfigured
        }
        
        guard let imageData = image.jpegData() else {
            throw PlatformError.postFailed("Failed to convert image to JPEG")
        }
        
        // Pinterest v5 API supports inline base64 image in pin creation
        let base64Image = imageData.base64EncodedString()
        
        let pin = try await createPinWithImage(
            base64Image: base64Image,
            boardID: board,
            title: String(caption.prefix(100)), // Pinterest title limit
            description: caption,
            link: link,
            token: token
        )
        
        logger.info("Pinterest pin created: \(pin.id)")
        
        return PostResult(
            success: true,
            postID: pin.id,
            postURL: URL(string: "https://pinterest.com/pin/\(pin.id)"),
            error: nil
        )
    }
    
    func postText(_ text: String) async throws -> PostResult {
        // Pinterest requires an image for all pins
        throw PlatformError.postFailed("Pinterest requires an image. Text-only posts are not supported.")
    }
    
    // MARK: - Board Discovery
    
    private func fetchFirstBoard(token: String) async throws {
        let url = URL(string: "https://api.pinterest.com/v5/boards")!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to fetch boards: \(errorBody)")
            throw PlatformError.postFailed("Failed to fetch Pinterest boards: \(errorBody)")
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
            throw PlatformError.postFailed("No Pinterest boards found. Create a board on Pinterest first.")
        }
        
        // Prefer boards with "wisdom" first, then "book"
        let targetBoard = boardsResponse.items.first(where: {
            $0.name.localizedCaseInsensitiveContains("wisdom")
        }) ?? boardsResponse.items.first(where: {
            $0.name.localizedCaseInsensitiveContains("book")
        }) ?? boardsResponse.items.first!
        
        boardID = targetBoard.id
        boardName = targetBoard.name
        
        // Persist to Keychain
        let creds = PinterestCredentials(boardID: targetBoard.id, boardName: targetBoard.name)
        try KeychainService.shared.save(creds, for: "pinterest_board")
        
        logger.info("Pinterest board connected: \(targetBoard.name) (ID: \(targetBoard.id))")
    }
    
    // MARK: - Pin Creation
    
    private func createPinWithImage(base64Image: String, boardID: String, title: String, description: String, link: URL, token: String) async throws -> (id: String, url: String?) {
        let url = URL(string: "https://api.pinterest.com/v5/pins")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "board_id": boardID,
            "media_source": [
                "source_type": "image_base64",
                "content_type": "image/jpeg",
                "data": base64Image
            ],
            "title": title,
            "description": description,
            "link": link.absoluteString
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PlatformError.postFailed("Pin creation failed: \(errorBody)")
        }
        
        struct PinResponse: Decodable {
            let id: String
            let link: String?
        }
        
        let pinResponse = try JSONDecoder().decode(PinResponse.self, from: data)
        return (pinResponse.id, pinResponse.link)
    }
}
