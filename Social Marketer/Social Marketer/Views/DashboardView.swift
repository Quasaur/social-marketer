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
    @State private var isPosting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
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
                    value: isSchedulerInstalled ? "9:00 AM" : "—",
                    icon: "clock"
                )
            }
            .padding(.horizontal)
            
            Divider()
            
            // Actions
            HStack(spacing: 16) {
                // Manual Post Button
                Button(action: manualPost) {
                    HStack {
                        if isPosting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        Text("Post Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPosting || enabledPlatformsCount == 0)
                
                // Scheduler Toggle
                Button(action: toggleScheduler) {
                    HStack {
                        Image(systemName: isSchedulerInstalled ? "stop.circle" : "play.circle")
                        Text(isSchedulerInstalled ? "Stop Scheduler" : "Start Scheduler")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Platform List
            VStack(alignment: .leading, spacing: 12) {
                Text("Platforms")
                    .font(.headline)
                
                if platforms.isEmpty {
                    Text("No platforms configured. Go to Settings to add platforms.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(platforms) { platform in
                        PlatformRow(platform: platform)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
        .onAppear {
            Task {
                isSchedulerInstalled = await scheduler.isLaunchAgentInstalled
            }
        }
        .alert("Social Marketer", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var enabledPlatformsCount: Int {
        platforms.filter { $0.isEnabled }.count
    }
    
    private var todaysPostCount: Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return recentPosts.filter { post in
            guard let postedDate = post.postedDate else { return false }
            return postedDate >= startOfDay
        }.count
    }
    
    // MARK: - Actions
    
    private func manualPost() {
        isPosting = true
        Task {
            await scheduler.executeScheduledPost()
            await MainActor.run {
                isPosting = false
                alertMessage = "Post completed! Check the logs for details."
                showingAlert = true
            }
        }
    }
    
    private func toggleScheduler() {
        Task {
            do {
                if isSchedulerInstalled {
                    try await scheduler.uninstallLaunchAgent()
                    await MainActor.run {
                        isSchedulerInstalled = false
                        alertMessage = "Scheduler stopped. Posts will not be automated."
                    }
                } else {
                    try await scheduler.installLaunchAgent()
                    await MainActor.run {
                        isSchedulerInstalled = true
                        alertMessage = "Scheduler started! Posts will run daily at 9:00 AM."
                    }
                }
                await MainActor.run { showingAlert = true }
            } catch {
                await MainActor.run {
                    alertMessage = "Error: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
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

// MARK: - Platform Row

struct PlatformRow: View {
    @ObservedObject var platform: Platform
    
    var body: some View {
        HStack {
            Image(systemName: platform.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(platform.isEnabled ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(platform.name ?? "Unknown")
                    .font(.body)
                if let lastPost = platform.lastPostDate {
                    Text("Last: \(lastPost, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { platform.isEnabled },
                set: { newValue in
                    platform.isEnabled = newValue
                    PersistenceController.shared.save()
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
