//
//  QuoteGraphicGenerator.swift
//  SocialMarketer
//
//  Generates quote graphics using Core Graphics (no external AI)
//

import AppKit
import CoreGraphics

/// Quote graphic generator service
final class QuoteGraphicGenerator {
    
    // MARK: - Constants
    
    let imageSize = CGSize(width: 1080, height: 1080)
    let backgroundColor = NSColor.black
    let textColor = NSColor.white
    let goldColor = NSColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1.0)
    let watermarkText = AppConfiguration.URLs.wisdomBookDomain
    
    // MARK: - Public Methods
    
    /// Generate a quote graphic from a wisdom entry
    func generate(from entry: WisdomEntry, template: BorderTemplate = .random) -> NSImage? {
        Log.graphic.info("Generating graphic for '\(entry.title)' with template \(template.displayName)")
        return generateImage(title: entry.title, content: entry.content, reference: entry.reference, template: template)
    }
    
    /// Generate a quote graphic from a cached wisdom entry
    func generate(from entry: CachedWisdomEntry, template: BorderTemplate = .random) -> NSImage? {
        Log.graphic.info("Generating graphic for cached entry '\(entry.title ?? "Unknown")' with template \(template.displayName)")
        return generateImage(title: entry.title ?? "Wisdom", content: entry.content ?? "", reference: entry.reference, template: template)
    }
    
    /// Core image generation logic
    private func generateImage(title: String, content: String, reference: String?, template: BorderTemplate) -> NSImage? {
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        
        backgroundColor.setFill()
        NSRect(origin: .zero, size: imageSize).fill()
        
        drawBorder(template: template)
        drawTitle(title)
        drawContent(content)
        
        if let reference = reference, !content.contains(reference) {
            drawReference(reference)
        }
        
        drawWatermark()
        
        image.unlockFocus()
        
        Log.graphic.debug("Graphic generated: \(Int(self.imageSize.width))×\(Int(self.imageSize.height)), template: \(template.displayName)")
        return image
    }
    
    /// Save image to file
    func save(_ image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            Log.graphic.error("Failed to create PNG data for save")
            Task { @MainActor in
                ErrorLog.shared.log(category: "Graphics", message: "Failed to create PNG data for save")
            }
            throw GeneratorError.saveFailed
        }
        try pngData.write(to: url)
        Log.graphic.info("Graphic saved to \(url.lastPathComponent)")
    }
    
    enum GeneratorError: Error {
        case saveFailed
    }
    
    // MARK: - Border Drawing
    
    func drawBorder(template: BorderTemplate) {
        goldColor.setStroke()
        goldColor.setFill()
        
        switch template {
        case .artDeco:          drawArtDecoBorder()
        case .classicScroll:    drawClassicScrollBorder()
        case .sacredGeometry:   drawSacredGeometryBorder()
        case .celticKnot:       drawCelticKnotBorder()
        case .fleurDeLis:       drawFleurDeLisBorder()
        case .baroque:          drawBaroqueBorder()
        case .victorian:        drawVictorianBorder()
        case .goldenVine:       drawGoldenVineBorder()
        case .stainedGlass:     drawStainedGlassBorder()
        case .modernGlow:       drawModernGlowBorder()
        }
    }
}
