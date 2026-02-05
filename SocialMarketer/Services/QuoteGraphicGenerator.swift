//
//  QuoteGraphicGenerator.swift
//  SocialMarketer
//
//  Generates quote graphics using Core Graphics (no external AI)
//

import AppKit
import CoreGraphics

/// Border template styles for quote graphics
enum BorderTemplate: String, CaseIterable {
    case artDeco = "art_deco"
    case greekLaurel = "greek_laurel"
    case sacredGeometry = "sacred_geometry"
    case celticKnot = "celtic_knot"
    case minimalist = "minimalist"
    case baroque = "baroque"
    case victorian = "victorian"
    case islamicGeometric = "islamic_geometric"
    case stainedGlass = "stained_glass"
    case modernGlow = "modern_glow"
    
    /// Display name
    var displayName: String {
        switch self {
        case .artDeco: return "Art Deco"
        case .greekLaurel: return "Greek Laurel"
        case .sacredGeometry: return "Sacred Geometry"
        case .celticKnot: return "Celtic Knot"
        case .minimalist: return "Minimalist"
        case .baroque: return "Baroque"
        case .victorian: return "Victorian"
        case .islamicGeometric: return "Islamic Geometric"
        case .stainedGlass: return "Stained Glass"
        case .modernGlow: return "Modern Glow"
        }
    }
    
    /// Get a random template
    static var random: BorderTemplate {
        allCases.randomElement()!
    }
}

/// Quote graphic generator service
final class QuoteGraphicGenerator {
    
    // MARK: - Constants
    
    private let imageSize = CGSize(width: 1080, height: 1080)
    private let backgroundColor = NSColor.black
    private let textColor = NSColor.white
    private let goldColor = NSColor(red: 212/255, green: 175/255, blue: 55/255, alpha: 1.0)
    private let watermarkText = "wisdombook.life"
    
    // MARK: - Public Methods
    
    /// Generate a quote graphic from a wisdom entry
    func generate(from entry: WisdomEntry, template: BorderTemplate = .random) -> NSImage? {
        let image = NSImage(size: imageSize)
        
        image.lockFocus()
        
        // Draw background
        backgroundColor.setFill()
        NSRect(origin: .zero, size: imageSize).fill()
        
        // Draw border (placeholder - will use actual border assets)
        drawBorder(template: template)
        
        // Draw title
        drawTitle(entry.title)
        
        // Draw content
        drawContent(entry.content)
        
        // Draw reference if exists
        if let reference = entry.reference {
            drawReference(reference)
        }
        
        // Draw watermark
        drawWatermark()
        
        image.unlockFocus()
        
        return image
    }
    
    /// Save image to file
    func save(_ image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw GeneratorError.saveFailed
        }
        try pngData.write(to: url)
    }
    
    enum GeneratorError: Error {
        case saveFailed
    }
    
    // MARK: - Private Drawing Methods
    
    private func drawBorder(template: BorderTemplate) {
        // Try to load border asset
        if let borderImage = NSImage(named: template.rawValue) {
            borderImage.draw(in: NSRect(origin: .zero, size: imageSize))
        } else {
            // Fallback: draw simple gold border
            drawSimpleBorder()
        }
    }
    
    private func drawSimpleBorder() {
        let borderRect = NSRect(x: 40, y: 40, width: imageSize.width - 80, height: imageSize.height - 80)
        goldColor.setStroke()
        let path = NSBezierPath(rect: borderRect)
        path.lineWidth = 4
        path.stroke()
        
        // Inner border
        let innerRect = NSRect(x: 50, y: 50, width: imageSize.width - 100, height: imageSize.height - 100)
        let innerPath = NSBezierPath(rect: innerRect)
        innerPath.lineWidth = 2
        innerPath.stroke()
    }
    
    private func drawTitle(_ title: String) {
        let font = NSFont.systemFont(ofSize: 48, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: centeredParagraphStyle()
        ]
        
        let titleRect = NSRect(x: 80, y: imageSize.height - 200, width: imageSize.width - 160, height: 80)
        title.uppercased().draw(in: titleRect, withAttributes: attributes)
    }
    
    private func drawContent(_ content: String) {
        let font = NSFont.systemFont(ofSize: 32, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: centeredParagraphStyle()
        ]
        
        let contentRect = NSRect(x: 100, y: 250, width: imageSize.width - 200, height: imageSize.height - 450)
        content.draw(in: contentRect, withAttributes: attributes)
    }
    
    private func drawReference(_ reference: String) {
        let font = NSFont.systemFont(ofSize: 24, weight: .light)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: goldColor,
            .paragraphStyle: centeredParagraphStyle()
        ]
        
        let refRect = NSRect(x: 100, y: 180, width: imageSize.width - 200, height: 50)
        ("- " + reference).draw(in: refRect, withAttributes: attributes)
    }
    
    private func drawWatermark() {
        let font = NSFont.systemFont(ofSize: 36, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: goldColor,
            .paragraphStyle: centeredParagraphStyle()
        ]
        
        let watermarkRect = NSRect(x: 100, y: 80, width: imageSize.width - 200, height: 60)
        watermarkText.draw(in: watermarkRect, withAttributes: attributes)
    }
    
    private func centeredParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }
}
