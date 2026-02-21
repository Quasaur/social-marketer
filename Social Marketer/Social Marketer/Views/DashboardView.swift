//
//  DashboardView.swift
//  SocialMarketer
//
//  Main dashboard showing platform status and scheduler controls
//

import SwiftUI

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Platform.name, ascending: true)],
        animation: .default
    ) private var platforms: FetchedResults<Platform>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Post.postedDate, ascending: false)],
        predicate: NSPredicate(format: "status == %@", PostStatus.posted.rawValue),
        animation: .default
    ) private var recentPosts: FetchedResults<Post>
    
    @State private var isSchedulerInstalled = false
    @State private var selectedPeriod: StatsPeriod = .allTime
    @StateObject private var analytics: PostingAnalytics
    @StateObject private var connectionHealth = ConnectionHealthService()
    
    private let scheduler = PostScheduler()
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _analytics = StateObject(wrappedValue: PostingAnalytics(context: context))
    }
    
    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Social Marketer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Wisdom Book Distribution Engine")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                // Scheduler status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(isSchedulerInstalled ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                    Text(isSchedulerInstalled ? "Scheduler Active" : "Scheduler Inactive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .id("dashboard-top")
            
            // Stats Cards
            HStack(spacing: 16) {
                DashboardCard(
                    title: "Active Platforms",
                    value: "\(enabledPlatformsCount)/\(platforms.count)",
                    icon: "square.stack.3d.up"
                )
                DashboardCard(
                    title: "Posted Today",
                    value: "\(todaysPostCount)",
                    icon: "checkmark.circle"
                )
                DashboardCard(
                    title: "Next Post",
                    value: isSchedulerInstalled ? nextPostTimeString : "—",
                    icon: "clock"
                )
            }
            .padding(.horizontal)
            
            // Connection Health Panel
            ConnectionStatusPanel(service: connectionHealth)
                .padding(.horizontal)
            
            // Analytics Section
            if let stats = analytics.currentStats {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Posting Analytics")
                            .font(.title2.bold())
                        
                        Spacer()
                        
                        Picker("Period", selection: $selectedPeriod) {
                            Text("7 Days").tag(StatsPeriod.last7Days)
                            Text("30 Days").tag(StatsPeriod.last30Days)
                            Text("All Time").tag(StatsPeriod.allTime)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 300)
                        .onChange(of: selectedPeriod) { _, newValue in
                            Task {
                                await analytics.fetchStats(period: newValue)
                            }
                        }
                    }
                    
                    // Overall Success Rate (Large)
                    HStack(spacing: 16) {
                        // Big success rate card
                        VStack(spacing: 8) {
                            Text(String(format: "%.1f%%", stats.successRate))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(successRateColor(stats.successRate))
                            Text("Overall Success Rate")
                                .font(.headline)
                            Text("\(stats.successCount) of \(stats.totalAttempts) attempts")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Platform breakdown
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Success by Platform")
                                .font(.headline)
                            
                            ForEach(stats.platformStats) { platform in
                                HStack {
                                    Text(platform.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.1f%%", platform.successRate))
                                        .font(.subheadline.bold())
                                        .foregroundColor(successRateColor(platform.successRate))
                                    Text("(\(platform.successCount)/\(platform.totalAttempts))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    //Top Errors
                    if !stats.topErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top Errors")
                                .font(.headline)
                            
                            ForEach(stats.topErrors.prefix(3), id: \.error) { errorItem in
                                HStack {
                                    Text(errorItem.error)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(errorItem.count)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            
            // Recent Errors
            ErrorLogView()
                .frame(minHeight: 300)
                .padding(.horizontal)
        }
        .padding(.top)
        .padding(.bottom)
        }
        .onAppear {
            proxy.scrollTo("dashboard-top", anchor: .top)
            Task {
                isSchedulerInstalled = await scheduler.isLaunchAgentInstalled
                await analytics.fetchStats(period: selectedPeriod)
                await connectionHealth.checkAll()
            }
        }
        }
    }
    
    // MARK: - Computed Properties
    
    private var enabledPlatformsCount: Int {
        platforms.filter { $0.isEnabled }.count
    }
    
    private var nextPostTimeString: String {
        var components = DateComponents()
        components.hour = PostScheduler.scheduledHour
        components.minute = PostScheduler.scheduledMinute
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(PostScheduler.scheduledHour):\(String(format: "%02d", PostScheduler.scheduledMinute))"
    }
    
    private var todaysPostCount: Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return recentPosts.filter { post in
            guard let postedDate = post.postedDate else { return false }
            return postedDate >= startOfDay
        }.count
    }
    
    private func successRateColor(_ rate: Double) -> Color {
        switch rate {
        case 90...100: return .green
        case 70..<90: return .orange
        default: return .red
        }
    }
    

}

// MARK: - Dashboard Card

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    DashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

// MARK: - Connection Status Panel

struct ConnectionStatusPanel: View {
    @ObservedObject var service: ConnectionHealthService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("External Connections")
                    .font(.headline)
                
                Spacer()
                
                if service.isChecking {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Checking…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    let issues = service.issueCount
                    if issues > 0 {
                        Text("\(issues) unreachable")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else if !service.results.isEmpty {
                        Text("All connected")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    
                    Button {
                        Task { await service.checkAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Recheck connections")
                }
            }
            
            if !service.results.isEmpty {
                let grouped = Dictionary(grouping: service.results) { $0.category }
                let categories = ConnectionResult.ConnectionCategory.allCases.filter { grouped[$0] != nil }
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 10) {
                    ForEach(categories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(category.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                            
                            ForEach(grouped[category] ?? []) { result in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(result.reachable ? Color.green : Color.red)
                                        .frame(width: 7, height: 7)
                                    Text(result.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                    if let ms = result.latencyMs {
                                        Text("\(ms)ms")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    } else {
                                        Text("—")
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}
