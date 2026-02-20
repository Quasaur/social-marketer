//
//  PlatformTierViews.swift
//  SocialMarketer
//
//  Shared tier data and views used by PlatformSettingsView
//

import SwiftUI

// MARK: - Platform Tier Data

enum PlatformTier {
    struct Item {
        let name: String
        let icon: String
        let note: String
    }
    
    static let apiAvailable: [Item] = [
        Item(name: "TikTok", icon: "music.note", note: "Content Posting API"),
        Item(name: "Threads", icon: "at", note: "Meta Threads API"),
        Item(name: "Bluesky", icon: "cloud.fill", note: "AT Protocol (open)"),
        Item(name: "Reddit", icon: "bubble.left.and.bubble.right.fill", note: "Reddit API")
    ]
    
    static let theRest: [Item] = [
        Item(name: "Substack", icon: "envelope.fill", note: "Newsletter / manual"),
        Item(name: "Medium", icon: "doc.text.fill", note: "API deprecated"),
        Item(name: "Tumblr", icon: "t.square.fill", note: "Limited API")
    ]
}

// MARK: - Tier Header

struct TierHeader: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int?
    let total: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            Spacer()
            if let count = count {
                Text("\(count)/\(total) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(total) platforms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Future Platform Row

struct FuturePlatformRow: View {
    let name: String
    let icon: String
    let note: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.tertiary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            Text("Coming soon")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}
