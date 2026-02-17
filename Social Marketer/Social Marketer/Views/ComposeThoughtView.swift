//
//  ComposeThoughtView.swift
//  SocialMarketer
//
//  Compose a manual Thought post with title and content
//

import SwiftUI

struct ComposeThoughtView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var title = ""
    @State private var content = ""
    @State private var showingPreview = false
    
    /// Temporary CachedWisdomEntry created from user input for graphic generation
    @State private var composedEntry: CachedWisdomEntry?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Title field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.headline)
                    TextField("e.g. NO WATER", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                
                // Content field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Content (English)")
                        .font(.headline)
                    TextEditor(text: $content)
                        .font(.body)
                        .frame(minHeight: 120, maxHeight: 200)
                        .border(Color.secondary.opacity(0.3), width: 1)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 16) {
                    Button("Cancel") {
                        cleanupEntry()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        prepareAndPreview()
                    } label: {
                        Label("Preview Graphic", systemImage: "eye")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                              content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Compose Thought")
            .frame(minWidth: 500, minHeight: 400)
            .sheet(isPresented: $showingPreview, onDismiss: {
                cleanupEntry()
                dismiss()
            }) {
                if let entry = composedEntry {
                    GraphicPreviewView(entry: entry, isManualThought: true)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
    }
    
    // MARK: - Private
    
    private func prepareAndPreview() {
        // Create a temporary CachedWisdomEntry from user input
        let entry = CachedWisdomEntry(context: viewContext)
        entry.id = UUID()
        entry.title = title.trimmingCharacters(in: .whitespaces).uppercased()
        entry.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.category = "Thought"
        entry.linkString = "https://www.wisdombook.life"
        entry.pubDate = Date()
        entry.fetchedAt = Date()
        entry.usedCount = 0
        
        composedEntry = entry
        showingPreview = true
    }
    
    private func cleanupEntry() {
        // Delete the temporary entry so it doesn't persist in Core Data
        if let entry = composedEntry {
            viewContext.delete(entry)
            try? viewContext.save()
            composedEntry = nil
        }
    }
}

#Preview {
    ComposeThoughtView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
