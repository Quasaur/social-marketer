//
//  ContentBrowserView.swift
//  SocialMarketer
//
//  Post History - displays posted content with image/video tracking
//

import SwiftUI

struct ContentBrowserView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Fetch only posted content, sorted by most recently posted first
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CachedWisdomEntry.lastUsedAt, ascending: false)],
        predicate: NSPredicate(format: "usedCount > 0"),
        animation: .default
    ) private var historyEntries: FetchedResults<CachedWisdomEntry>
    
    @State private var selectedCategory: WisdomEntry.WisdomCategory? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedEntry: CachedWisdomEntry? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Post History")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(filteredEntries.count) posted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Total stats
                HStack(spacing: 16) {
                    Label("\(totalImagePosts)", systemImage: "photo.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Label("\(totalVideoPosts)", systemImage: "video.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            
            // Category Filter
            Picker("Category", selection: $selectedCategory) {
                Text("All").tag(nil as WisdomEntry.WisdomCategory?)
                Text("Thoughts").tag(WisdomEntry.WisdomCategory.thought as WisdomEntry.WisdomCategory?)
                Text("Quotes").tag(WisdomEntry.WisdomCategory.quote as WisdomEntry.WisdomCategory?)
                Text("Passages").tag(WisdomEntry.WisdomCategory.passage as WisdomEntry.WisdomCategory?)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 12)
            
            Divider()
            
            // Entry List
            if filteredEntries.isEmpty {
                emptyState
            } else {
                List(filteredEntries) { entry in
                    HistoryEntryRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEntry = entry
                        }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            HistoryDetailSheet(entry: entry)
        }
        .alert("Post History", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredEntries: [CachedWisdomEntry] {
        guard let category = selectedCategory else {
            return Array(historyEntries)
        }
        return historyEntries.filter { $0.wisdomCategory == category }
    }
    
    private var totalImagePosts: Int {
        historyEntries.reduce(0) { $0 + Int($1.postedImageCount) }
    }
    
    private var totalVideoPosts: Int {
        historyEntries.reduce(0) { $0 + Int($1.postedVideoCount) }
    }
    
    // MARK: - Views
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Posted Content Yet")
                .font(.headline)
            Text("Content will appear here after it's posted to your platforms")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Entry Row

struct HistoryEntryRow: View {
    @ObservedObject var entry: CachedWisdomEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Category Badge
                Text(entry.wisdomCategory.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(categoryColor.opacity(0.15))
                    .foregroundStyle(categoryColor)
                    .cornerRadius(4)
                
                Spacer()
                
                // Post count indicators
                HStack(spacing: 8) {
                    if entry.postedImageCount > 0 {
                        Label("\(entry.postedImageCount)", systemImage: "photo.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    if entry.postedVideoCount > 0 {
                        Label("\(entry.postedVideoCount)", systemImage: "video.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                
                // Last posted date
                if let lastUsed = entry.lastUsedAt {
                    Text(lastUsed, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Title
            Text(entry.title ?? "Untitled")
                .font(.headline)
                .lineLimit(2)
            
            // Content Preview
            Text(entry.content ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            // Reference if available
            if let reference = entry.reference, !reference.isEmpty {
                Text("— \(reference)")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var categoryColor: Color {
        switch entry.wisdomCategory {
        case .thought: return .blue
        case .quote: return .purple
        case .passage: return .orange
        case .introduction: return .green
        }
    }
}

// MARK: - Detail Sheet

struct HistoryDetailSheet: View {
    let entry: CachedWisdomEntry
    @Environment(\.dismiss) private var dismiss
    @State private var showingGraphicPreview = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Category Badge
                    HStack {
                        Text(entry.wisdomCategory.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .cornerRadius(6)
                        
                        Spacer()
                        
                        // Post counts
                        HStack(spacing: 12) {
                            if entry.postedImageCount > 0 {
                                Label("\(entry.postedImageCount) image post(s)", systemImage: "photo.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                            if entry.postedVideoCount > 0 {
                                Label("\(entry.postedVideoCount) video post(s)", systemImage: "video.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    // Title
                    Text(entry.title ?? "Untitled")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Divider()
                    
                    // Content
                    Text(entry.content ?? "")
                        .font(.body)
                    
                    // Reference
                    if let reference = entry.reference, !reference.isEmpty {
                        Text("— \(reference)")
                            .font(.body)
                            .italic()
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                    
                    Divider()
                    
                    // Post History Metadata
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Post History")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        
                        if let lastUsed = entry.lastUsedAt {
                            Label("Last posted: \(lastUsed, style: .date)", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Label("Total posts: \(entry.usedCount)", systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if entry.postedImageCount > 0 {
                            Label("Image posts: \(entry.postedImageCount)", systemImage: "photo")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        
                        if entry.postedVideoCount > 0 {
                            Label("Video posts: \(entry.postedVideoCount)", systemImage: "video")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Divider()
                    
                    // Link
                    if let link = entry.link {
                        Link(destination: link) {
                            Label("View on wisdombook.life", systemImage: "link")
                                .font(.caption)
                        }
                    }
                    
                    // Regenerate Graphic button
                    Button {
                        showingGraphicPreview = true
                    } label: {
                        Label("Generate Graphic", systemImage: "photo.artframe")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Post Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingGraphicPreview) {
                GraphicPreviewView(entry: entry)
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}

#Preview {
    ContentBrowserView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
