//
//  QueueView.swift
//  SocialMarketer
//
//  View for managing scheduled and completed posts
//

import SwiftUI

struct QueueView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Post.scheduledDate, ascending: true)],
        predicate: NSPredicate(format: "status == %@", PostStatus.pending.rawValue),
        animation: .default
    ) private var pendingPosts: FetchedResults<Post>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Post.postedDate, ascending: false)],
        predicate: NSPredicate(format: "status == %@", PostStatus.posted.rawValue),
        animation: .default
    ) private var postedPosts: FetchedResults<Post>
    
    @State private var isPosting = false
    @State private var postResult: String?
    @State private var showingResult = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var schedulerInstalled = false
    @State private var scheduledTime: Date = {
        var components = DateComponents()
        components.hour = PostScheduler.scheduledHour
        components.minute = PostScheduler.scheduledMinute
        return Calendar.current.date(from: components) ?? Date()
    }()
    
    private let scheduler = PostScheduler()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Post Queue")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            Text("Manage scheduled and completed posts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            // Action Buttons
            HStack(spacing: 12) {
                // Manual Post button
                Button {
                    Task { await postNow() }
                } label: {
                    HStack {
                        if isPosting {
                            ProgressView()
                                .controlSize(.small)
                            Text("Posting to all platforms...")
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Manual Post")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPosting)
                .help("Fetch random wisdom from RSS, generate graphic, and post to all connected platforms")
                
                Spacer()
                
                // Scheduler toggle + time picker
                HStack(spacing: 8) {
                    Image(systemName: schedulerInstalled ? "clock.badge.checkmark" : "clock")
                        .foregroundStyle(schedulerInstalled ? .green : .orange)
                    
                    Toggle("Daily Scheduler", isOn: $schedulerInstalled)
                        .toggleStyle(.status)
                        .onChange(of: schedulerInstalled) { _, newValue in
                            toggleScheduler(enabled: newValue)
                        }
                    
                    DatePicker("", selection: $scheduledTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .frame(width: 90)
                        .onChange(of: scheduledTime) { _, newTime in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
                            PostScheduler.scheduledHour = components.hour ?? 9
                            PostScheduler.scheduledMinute = components.minute ?? 0
                            if schedulerInstalled {
                                toggleScheduler(enabled: true) // reinstall with new time
                            }
                        }
                }
                .help("Install a macOS Launch Agent to automatically post daily at the selected time")
            }
            .padding(.horizontal)
            
            List {
                // Pending Section
                Section {
                    if pendingPosts.isEmpty {
                        Text("No scheduled posts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(pendingPosts) { post in
                            QueueRow(post: post)
                        }
                        .onDelete(perform: deletePosts)
                    }
                } header: {
                    Label("Pending (\(pendingPosts.count))", systemImage: "clock")
                }
                
                // Posted Section
                Section {
                    if postedPosts.isEmpty {
                        Text("No posts yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        ForEach(postedPosts.prefix(20)) { post in
                            QueueRow(post: post)
                        }
                    }
                } header: {
                    Label("Posted", systemImage: "checkmark.circle")
                }
            }
            .listStyle(.inset)
        }
        .padding(.top)
        .onAppear {
            schedulerInstalled = scheduler.isLaunchAgentInstalled
        }
        .alert("Post Result", isPresented: $showingResult) {
            Button("OK") {}
        } message: {
            Text(postResult ?? "")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Post Now
    
    private func postNow() async {
        isPosting = true
        defer { isPosting = false }
        
        await scheduler.executeScheduledPost()
        
        postResult = "Wisdom posted to all connected platforms! 🎉\nCheck the Posted section below for results."
        showingResult = true
    }
    
    // MARK: - Scheduler Toggle
    
    private func toggleScheduler(enabled: Bool) {
        do {
            if enabled {
                try scheduler.installLaunchAgent()
            } else {
                try scheduler.uninstallLaunchAgent()
            }
        } catch {
            errorMessage = "Scheduler error: \(error.localizedDescription)"
            showingError = true
            schedulerInstalled = !enabled // revert toggle
        }
    }
    
    private func deletePosts(at offsets: IndexSet) {
        for index in offsets {
            let post = pendingPosts[index]
            viewContext.delete(post)
        }
        PersistenceController.shared.save()
    }
}

// MARK: - Queue Row

struct QueueRow: View {
    @ObservedObject var post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 24)
            
            // Content preview
            VStack(alignment: .leading, spacing: 4) {
                Text(post.content?.prefix(60) ?? "No content")
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let scheduled = post.scheduledDate {
                        Text(scheduled, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let link = post.link {
                        Text(link.host ?? "")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            // Platform badges (from logs)
            if let logs = post.logs as? Set<PostLog> {
                HStack(spacing: 4) {
                    ForEach(Array(logs.prefix(3)), id: \.id) { log in
                        if log.success {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch post.postStatus {
        case .pending: return "clock"
        case .posted: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch post.postStatus {
        case .pending: return .orange
        case .posted: return .green
        case .failed: return .red
        }
    }
}

#Preview {
    QueueView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
