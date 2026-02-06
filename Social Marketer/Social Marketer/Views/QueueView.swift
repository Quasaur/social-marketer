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
