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
    
    private let scheduler = PostScheduler()
    
    var body: some View {
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
            
            // Recent Errors
            ErrorLogView()
                .frame(maxHeight: .infinity)
        }
        .padding(.top)
        .onAppear {
            Task {
                isSchedulerInstalled = await scheduler.isLaunchAgentInstalled
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
