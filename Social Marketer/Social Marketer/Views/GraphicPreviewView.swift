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
    
    @State private var selectedTemplate: BorderTemplate = .artDeco
    @State private var generatedImage: NSImage? = nil
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    
    private let generator = QuoteGraphicGenerator()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Template Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Border Style")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
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
                        .padding(.horizontal, 4)
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
                    .buttonStyle(.borderedProminent)
                    .disabled(generatedImage == nil || isSaving)
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
        }
        .frame(minWidth: 600, minHeight: 700)
        .onAppear {
            regenerate()
        }
    }
    
    // MARK: - Actions
    
    private func regenerate() {
        generatedImage = generator.generate(from: entry, template: selectedTemplate)
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
