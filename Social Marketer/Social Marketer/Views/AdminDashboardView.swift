//
//  AdminDashboardView.swift
//  Social Marketer
//
//  Wisdom Book activity monitoring dashboard
//

import SwiftUI

struct AdminDashboardView: View {
    
    // MARK: - State
    
    @State private var members: [WisdomBookAdminService.Member] = []
    @State private var tips: [WisdomBookAdminService.KofiTip] = []
    @State private var summary: WisdomBookAdminService.ActivitySummary?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastUpdated: Date?
    
    private let adminService = WisdomBookAdminService()
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                errorView(error)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Summary Statistics
                        if let summary = summary {
                            summarySection(summary)
                        }
                        
                        Divider()
                        
                        // Recent Members
                        recentMembersSection
                        
                        Divider()
                        
                        // Recent Ko-fi Tips
                        recentTipsSection
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Wisdom Book Dashboard")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            if let lastUpdated = lastUpdated {
                Text("Updated: \(lastUpdated, style: .time)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                Task {
                    await loadData()
                }
            }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Summary Section
    
    private func summarySection(_ summary: WisdomBookAdminService.ActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Summary")
                .font(.headline)
            
            HStack(spacing: 20) {
                // Users Stats
                statCard(
                    title: "Total Members",
                    value: "\(summary.users.total)",
                    subtitle: "+\(summary.users.last7Days) this week",
                    color: .blue
                )
                
                // Ko-fi Stats
                statCard(
                    title: "Total Tips",
                    value: "\(summary.kofiTips.total)",
                    subtitle: "+\(summary.kofiTips.last7Days) this week",
                    color: .green
                )
                
                // Revenue Stats
                statCard(
                    title: "Revenue (30d)",
                    value: String(format: "$%.2f", summary.revenue.amountValue),
                    subtitle: "\(summary.kofiTips.activeSubscriptions) subscriptions",
                    color: .orange
                )
            }
        }
    }
    
    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Recent Members Section
    
    private var recentMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Members")
                    .font(.headline)
                Spacer()
                Text("\(members.count) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if members.isEmpty {
                Text("No recent members")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(members) { member in
                    memberRow(member)
                }
            }
        }
    }
    
    private func memberRow(_ member: WisdomBookAdminService.Member) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if member.isGuardian {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                    
                    badgeForTier(member.kofiBadge)
                }
                
                Text(member.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let date = member.joinedDate {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
    
    // MARK: - Recent Tips Section
    
    private var recentTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Ko-fi Tips")
                    .font(.headline)
                Spacer()
                Text("\(tips.count) tips")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if tips.isEmpty {
                Text("No recent tips")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(tips) { tip in
                    tipRow(tip)
                }
            }
        }
    }
    
    private func tipRow(_ tip: WisdomBookAdminService.KofiTip) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(tip.fromName)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    if tip.isSubscription {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat.circle.fill")
                                .font(.caption2)
                            Text("MONTHLY SUBSCRIBER")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue)
                        .cornerRadius(4)
                    }
                }
                
                if let linkedUser = tip.linkedUser {
                    // Find the member to show their email
                    if let member = members.first(where: { $0.username == linkedUser.username || $0.nickname == linkedUser.nickname }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Linked Member: \(linkedUser.displayName)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            Text("Email: \(member.email)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Linked Member: \(linkedUser.displayName)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                
                if let message = tip.message, !message.isEmpty {
                    Text("\"\(message)\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                if let tierName = tip.tierName, !tierName.isEmpty {
                    Text(tierName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "$%.2f", tip.amountValue))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                if let date = tip.tipDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
         }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(tip.isSubscription ? Color.blue.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tip.isSubscription ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    
    private func badgeForTier(_ tier: String) -> some View {
        Group {
            if tier != "regular" {
                Text(tier.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(badgeColor(for: tier))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
    }
    
    private func badgeColor(for tier: String) -> Color {
        switch tier.lowercased() {
        case "partner":
            return .purple
        case "supporter":
            return .orange
        case "tipper":
            return .green
        default:
            return .gray
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Error")
                .font(.headline)
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await loadData()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let membersResponse = adminService.fetchRecentMembers(days: 30)
            async let tipsResponse = adminService.fetchRecentTips(days: 30)
            async let summaryResponse = adminService.fetchActivitySummary()
            
            let (membersData, tipsData, summaryData) = try await (membersResponse, tipsResponse, summaryResponse)
            
            await MainActor.run {
                self.members = membersData.members
                self.tips = tipsData.tips
                self.summary = summaryData
                self.lastUpdated = Date()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AdminDashboardView()
        .frame(width: 900, height: 700)
}
