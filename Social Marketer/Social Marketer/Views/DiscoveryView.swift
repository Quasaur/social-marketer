//
//  DiscoveryView.swift
//  SocialMarketer
//
//  Panel for Search Engines, Web Directories, and RSS Aggregators
//

import SwiftUI
import UniformTypeIdentifiers

struct DiscoveryView: View {
    // Google Search Console state
    @State private var gscConfigured = false
    @State private var gscEmail: String?
    @State private var gscTesting = false
    @State private var showingFilePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var successMessage = ""
    private let googleIndexing = GoogleIndexingConnector()
    
    // Section expansion state
    @State private var searchEnginesExpanded = true
    @State private var webDirectoriesExpanded = false
    @State private var rssExpanded = false
    
    // Feedly state
    @AppStorage("feedlySetUp") private var feedlySetUp = false
    private static let feedlyFeedURL = "https://wisdombook.life/feed/wisdom.xml"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Discovery & Indexing")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
            
            Text("Get your content discovered by search engines, directories, and feed readers.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Search Engines
                    DisclosureGroup(isExpanded: $searchEnginesExpanded) {
                        VStack(spacing: 0) {
                            GoogleSearchConsoleRow(
                                isConfigured: gscConfigured,
                                email: gscEmail,
                                isTesting: gscTesting,
                                onImport: { showingFilePicker = true },
                                onTest: { Task { await testGooglePing() } },
                                onRemove: { removeGSCKey() }
                            )
                            
                            Divider().padding(.leading, 60)
                            
                            DiscoveryPlaceholderRow(
                                name: "Bing Webmaster Tools",
                                icon: "globe.americas.fill",
                                note: "Microsoft Bing indexing"
                            )
                        }
                    } label: {
                        DiscoveryTierHeader(
                            title: "Search Engines",
                            icon: "magnifyingglass.circle.fill",
                            color: .blue,
                            count: gscConfigured ? 1 : 0,
                            total: 2
                        )
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    
                    // Web Directories
                    DisclosureGroup(isExpanded: $webDirectoriesExpanded) {
                        VStack(spacing: 0) {
                            DiscoveryPlaceholderRow(
                                name: "Curlie (DMOZ)",
                                icon: "list.bullet.rectangle",
                                note: "Open directory project"
                            )
                            Divider().padding(.leading, 60)
                            DiscoveryPlaceholderRow(
                                name: "Best of the Web",
                                icon: "star.circle.fill",
                                note: "Curated web directory"
                            )
                            Divider().padding(.leading, 60)
                            DiscoveryPlaceholderRow(
                                name: "Jasmine Directory",
                                icon: "leaf.fill",
                                note: "Quality web directory"
                            )
                        }
                    } label: {
                        DiscoveryTierHeader(
                            title: "Web Directories",
                            icon: "folder.fill",
                            color: .orange,
                            count: nil,
                            total: 3
                        )
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                    
                    // RSS Aggregators
                    DisclosureGroup(isExpanded: $rssExpanded) {
                        VStack(spacing: 0) {
                            FeedlyRow(
                                isSetUp: feedlySetUp,
                                onCopyURL: { copyFeedlyURL() },
                                onOpenFeedly: { openFeedly() },
                                onToggleSetup: { feedlySetUp.toggle() }
                            )
                            Divider().padding(.leading, 60)
                            DiscoveryPlaceholderRow(
                                name: "Flipboard",
                                icon: "rectangle.grid.2x2.fill",
                                note: "Social magazine platform"
                            )
                            Divider().padding(.leading, 60)
                            DiscoveryPlaceholderRow(
                                name: "NewsBlur",
                                icon: "newspaper.fill",
                                note: "Personal news reader"
                            )
                        }
                    } label: {
                        DiscoveryTierHeader(
                            title: "RSS Aggregators",
                            icon: "dot.radiowaves.up.forward",
                            color: .purple,
                            count: feedlySetUp ? 1 : nil,
                            total: 3
                        )
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            Spacer(minLength: 0)
            
            // Info Footer
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                Text("All credentials are stored securely in your Mac's Keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
        }
        .frame(minWidth: 500, minHeight: 500)
        .onAppear {
            gscConfigured = googleIndexing.isConfigured
            gscEmail = googleIndexing.serviceAccountEmail
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") {}
        } message: {
            Text(successMessage)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleGSCKeyImport(result)
        }
    }
    
    // MARK: - Google Search Console
    
    private func handleGSCKeyImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Cannot access the selected file"
                showingError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                try googleIndexing.importServiceAccountKey(from: url)
                gscConfigured = true
                gscEmail = googleIndexing.serviceAccountEmail
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func testGooglePing() async {
        gscTesting = true
        defer { gscTesting = false }
        
        do {
            let testURL = URL(string: "https://wisdombook.life")!
            try await googleIndexing.notifyURLUpdated(testURL)
            successMessage = "✅ Test ping sent successfully to Google for wisdombook.life"
            showingSuccess = true
        } catch {
            errorMessage = "Test ping failed: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func removeGSCKey() {
        do {
            try googleIndexing.removeServiceAccountKey()
            gscConfigured = false
            gscEmail = nil
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    // MARK: - Feedly Helpers
    
    private func copyFeedlyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.feedlyFeedURL, forType: .string)
        successMessage = "Feed URL copied to clipboard"
        showingSuccess = true
    }
    
    private func openFeedly() {
        let feedlySubscribeURL = "https://feedly.com/i/subscription/feed/\(Self.feedlyFeedURL)"
        if let url = URL(string: feedlySubscribeURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Discovery Tier Header

struct DiscoveryTierHeader: View {
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
                Text("\(total) services")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Discovery Placeholder Row

struct DiscoveryPlaceholderRow: View {
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
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Feedly Row

struct FeedlyRow: View {
    let isSetUp: Bool
    let onCopyURL: () -> Void
    let onOpenFeedly: () -> Void
    let onToggleSetup: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "dot.radiowaves.right")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Feedly")
                    .font(.headline)
                
                if isSetUp {
                    Text("✅ Set up — wisdombook.life/feed/wisdom.xml")
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(1)
                } else {
                    Text("wisdombook.life/feed/wisdom.xml")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button("Copy Feed URL") { onCopyURL() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                Button("Open Feedly") { onOpenFeedly() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                if isSetUp {
                    Button(role: .destructive) {
                        onToggleSetup()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Mark as not set up")
                } else {
                    Button("Mark Done") { onToggleSetup() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Google Search Console Row

struct GoogleSearchConsoleRow: View {
    let isConfigured: Bool
    let email: String?
    let isTesting: Bool
    let onImport: () -> Void
    let onTest: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text("Google Search Console")
                    .font(.headline)
                
                if isConfigured, let email = email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(1)
                } else {
                    Text("Import service account key")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Actions
            if isConfigured {
                HStack(spacing: 8) {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Test Ping") { onTest() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                Button("Import Key") { onImport() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    DiscoveryView()
}
