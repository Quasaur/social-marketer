//
//  QuoteGraphicGenerator.swift
//  SocialMarketer
//
//  Generates quote graphics using Core Graphics (no external AI)
//

import AppKit
import CoreGraphics

/// Border template styles for quote graphics
enum BorderTemplate: String, CaseIterable, Identifiable {
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
    
    var id: String { rawValue }
    
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
    
    /// Actual filename in Resources/Borders
    var filename: String {
        switch self {
        case .artDeco: return "template_01_art_deco_1770307365733"
        case .greekLaurel: return "template_02_greek_laurel_1770307380099"
        case .sacredGeometry: return "template_03_sacred_geometry_1770307394997"
        case .celticKnot: return "template_04_celtic_knot_1770307423874"
        case .minimalist: return "template_05_minimalist_1770307439021"
        case .baroque: return "template_06_baroque_1770307454492"
        case .victorian: return "template_07_victorian_1770307484325"
        case .islamicGeometric: return "template_08_islamic_1770307499223"
        case .stainedGlass: return "template_09_stained_glass_1770307514480"
        case .modernGlow: return "template_10_modern_glow_1770307534790"
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
        
        // Draw background
        backgroundColor.setFill()
        NSRect(origin: .zero, size: imageSize).fill()
        
        // Draw border
        drawBorder(template: template)
        
        // Draw title
        drawTitle(title)
        
        // Draw content
        drawContent(content)
        
        // Draw reference if exists
        if let reference = reference {
            drawReference(reference)
        }
        
        // Draw watermark
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
    
    // MARK: - Private Drawing Methods
    
    private func drawBorder(template: BorderTemplate) {
        // Load border image from bundle Resources/Borders
        if let bundlePath = Bundle.main.path(forResource: template.filename, ofType: "png", inDirectory: "Borders"),
           let borderImage = NSImage(contentsOfFile: bundlePath) {
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
