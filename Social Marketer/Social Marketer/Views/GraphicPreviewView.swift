//
//  GraphicPreviewView.swift
//  SocialMarketer
//
//  Preview and export quote graphics with template selection
//

import SwiftUI
import AppKit

struct GraphicPreviewView: View {
    let entry: CachedWisdomEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedTemplate: BorderTemplate = .artDeco
    @State private var generatedImage: NSImage? = nil
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    @State private var showingQueueSheet = false
    @State private var scheduledDate = Date()
    @State private var showingQueueSuccess = false
    
    private let generator = QuoteGraphicGenerator()
    
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Template Picker - 2 rows of 5
                VStack(alignment: .leading, spacing: 8) {
                    Text("Border Style")
                        .font(.headline)
                    
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(BorderTemplate.allCases) { template in
                            TemplateButton(
                                template: template,
                                isSelected: selectedTemplate == template
                            ) {
                                selectedTemplate = template
                                regenerate()
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Preview
                if let image = generatedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 500, maxHeight: 500)
                        .cornerRadius(8)
                        .shadow(radius: 8)
                } else {
                    ProgressView("Generating...")
                        .frame(width: 300, height: 300)
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 16) {
                    Button("Regenerate") {
                        regenerate()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: saveImage) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Label("Save to Desktop", systemImage: "square.and.arrow.down")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(generatedImage == nil || isSaving)
                    
                    Button(action: { showingQueueSheet = true }) {
                        Label("Add to Queue", systemImage: "tray.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(generatedImage == nil)
                }
                .padding(.bottom)
            }
            .padding(.top)
            .navigationTitle("Generate Graphic")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Saved!", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Quote graphic saved to Desktop.")
            }
            .alert("Queued!", isPresented: $showingQueueSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Post scheduled for \(scheduledDate.formatted(date: .abbreviated, time: .shortened)).")
            }
            .sheet(isPresented: $showingQueueSheet) {
                QueueScheduleSheet(
                    scheduledDate: $scheduledDate,
                    onConfirm: addToQueue
                )
            }
        }
        .frame(minWidth: 600, minHeight: 750)
        .onAppear {
            regenerate()
        }
    }
    
    // MARK: - Actions
    
    private func regenerate() {
        // Clear and regenerate to force SwiftUI refresh
        generatedImage = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            generatedImage = generator.generate(from: entry, template: selectedTemplate)
        }
    }
    
    private func saveImage() {
        guard let image = generatedImage else { return }
        isSaving = true
        
        Task {
            do {
                let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let filename = "wisdom_\(entry.wisdomCategory.rawValue.lowercased())_\(Date().timeIntervalSince1970).png"
                let fileURL = desktopURL.appendingPathComponent(filename)
                
                try generator.save(image, to: fileURL)
                
                await MainActor.run {
                    isSaving = false
                    showingSaveSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    private func addToQueue() {
        guard let image = generatedImage, let entryLink = entry.link else { return }
        
        Task {
            do {
                // Save image to app support directory
                let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let queueDir = appSupport.appendingPathComponent("SocialMarketer/Queue", isDirectory: true)
                try FileManager.default.createDirectory(at: queueDir, withIntermediateDirectories: true)
                
                let filename = "queued_\(Date().timeIntervalSince1970).png"
                let imageURL = queueDir.appendingPathComponent(filename)
                try generator.save(image, to: imageURL)
                
                // Create Post entity
                await MainActor.run {
                    let post = Post(context: viewContext, content: entry.content ?? "", imageURL: imageURL, link: entryLink)
                    post.scheduledDate = scheduledDate
                    entry.markAsUsed()
                    PersistenceController.shared.save()
                    showingQueueSuccess = true
                }
            } catch {
                // Handle error silently for now
            }
        }
    }
}

// MARK: - Template Button

struct TemplateButton: View {
    let template: BorderTemplate
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .overlay(
                        Text(String(template.displayName.prefix(3)))
                            .font(.caption2)
                            .fontWeight(.medium)
                    )
                
                Text(template.displayName)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Queue Schedule Sheet

struct QueueScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var scheduledDate: Date
    let onConfirm: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Schedule Post")
                .font(.headline)
            
            Text("Choose when to post this wisdom quote.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            DatePicker(
                "Post Date",
                selection: $scheduledDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .frame(maxHeight: 300)
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Add to Queue") {
                    dismiss()
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350)
    }
}

#Preview {
    GraphicPreviewView(entry: {
        let context = PersistenceController.preview.container.viewContext
        let entry = CachedWisdomEntry(context: context)
        entry.title = "AGAPE"
        entry.content = "Love is patient, love is kind. It does not envy, it does not boast."
        entry.reference = "1 Corinthians 13:4"
        entry.category = "Quote"
        return entry
    }())
}
