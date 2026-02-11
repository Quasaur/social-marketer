//
//  ErrorLogView.swift
//  SocialMarketer
//
//  Displays recent errors with category badges and timestamps.
//

import SwiftUI

struct ErrorLogView: View {
    @ObservedObject private var errorLog = ErrorLog.shared
    @State private var selectedEntry: ErrorEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Errors")
                    .font(.title2.bold())
                
                if !errorLog.entries.isEmpty {
                    Text("\(errorLog.entries.count)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                }
                
                Spacer()
                
                if !errorLog.entries.isEmpty {
                    Button(role: .destructive) {
                        errorLog.clear()
                    } label: {
                        Label("Clear All", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            Divider()
            
            if errorLog.entries.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("No Recent Errors")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                    Text("Errors from platform connectors, RSS feeds,\nand other services will appear here.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Error list
                List(errorLog.entries, selection: $selectedEntry) { entry in
                    ErrorEntryRow(entry: entry)
                        .tag(entry)
                }
                .listStyle(.inset)
            }
        }
    }
}

// MARK: - Error Entry Row

struct ErrorEntryRow: View {
    let entry: ErrorEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                // Category badge
                Text(entry.category)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(badgeColor(for: entry.category))
                    )
                
                // Message
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.message)
                        .font(.body)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    Text(entry.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if entry.detail != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Detail (expanded)
            if isExpanded, let detail = entry.detail {
                Text(detail)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
            }
        }
        .padding(.vertical, 4)
    }
    
    private func badgeColor(for category: String) -> Color {
        switch category {
        case "App":         return .blue
        case "Scheduler":   return .orange
        case "Persistence": return .purple
        case "Twitter":     return .cyan
        case "Instagram":   return .pink
        case "LinkedIn":    return .indigo
        case "Facebook":    return .blue
        case "Pinterest":   return .red
        case "RSS":         return .green
        case "Graphics":    return .mint
        case "Keychain":    return .brown
        default:            return .gray
        }
    }
}

#Preview {
    ErrorLogView()
}
