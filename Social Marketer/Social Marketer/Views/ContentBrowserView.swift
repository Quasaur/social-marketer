//
//  ContentBrowserView.swift
//  SocialMarketer
//
//  Browse and select wisdom entries from the RSS feed cache
//

import SwiftUI

struct ContentBrowserView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CachedWisdomEntry.pubDate, ascending: false)],
        animation: .default
    ) private var entries: FetchedResults<CachedWisdomEntry>
    
    @State private var isRefreshing = false
    @State private var selectedCategory: WisdomEntry.WisdomCategory? = nil
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedEntry: CachedWisdomEntry? = nil
    
    private let contentService = ContentService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Content Library")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(filteredEntries.count) entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Refresh Button
                Button(action: refreshContent) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRefreshing)
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
                    ContentEntryRow(entry: entry)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEntry = entry
                        }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            ContentDetailSheet(entry: entry)
        }
        .alert("Content Library", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredEntries: [CachedWisdomEntry] {
        guard let category = selectedCategory else {
            return Array(entries)
        }
        return entries.filter { $0.wisdomCategory == category }
    }
    
    // MARK: - Views
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Entries Yet")
                .font(.headline)
            Text("Tap Refresh to fetch wisdom content from wisdombook.life")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Refresh Now") {
                refreshContent()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func refreshContent() {
        isRefreshing = true
        Task {
            do {
                let newCount = try await contentService.refreshContent()
                await MainActor.run {
                    isRefreshing = false
                    if newCount > 0 {
                        alertMessage = "Added \(newCount) new entries!"
                    } else {
                        alertMessage = "Content is up to date."
                    }
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    isRefreshing = false
                    alertMessage = "Error: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Entry Row

struct ContentEntryRow: View {
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
                
                // Used indicator
                if entry.usedCount > 0 {
                    Label("\(entry.usedCount)", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                
                // Date
                if let pubDate = entry.pubDate {
                    Text(pubDate, style: .date)
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
        }
    }
}

// MARK: - Detail Sheet

struct ContentDetailSheet: View {
    let entry: CachedWisdomEntry
    @Environment(\.dismiss) private var dismiss
    
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
                        
                        if entry.usedCount > 0 {
                            Text("Used \(entry.usedCount) time(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 4) {
                        if let pubDate = entry.pubDate {
                            Label("Published: \(pubDate, style: .date)", systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let fetchedAt = entry.fetchedAt {
                            Label("Cached: \(fetchedAt, style: .relative) ago", systemImage: "arrow.down.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let link = entry.link {
                            Link(destination: link) {
                                Label("View on wisdombook.life", systemImage: "link")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Entry Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
    }
}

#Preview {
    ContentBrowserView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
