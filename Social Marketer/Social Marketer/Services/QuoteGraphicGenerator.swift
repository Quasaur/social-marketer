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
    case classicScroll = "classic_scroll"
    case sacredGeometry = "sacred_geometry"
    case celticKnot = "celtic_knot"
    case fleurDeLis = "fleur_de_lis"
    case baroque = "baroque"
    case victorian = "victorian"
    case goldenVine = "golden_vine"
    case stainedGlass = "stained_glass"
    case modernGlow = "modern_glow"
    
    var id: String { rawValue }
    
    /// Display name
    var displayName: String {
        switch self {
        case .artDeco: return "Art Deco"
        case .classicScroll: return "Classic Scroll"
        case .sacredGeometry: return "Sacred Geometry"
        case .celticKnot: return "Celtic Knot"
        case .fleurDeLis: return "Fleur-de-lis"
        case .baroque: return "Baroque"
        case .victorian: return "Victorian"
        case .goldenVine: return "Golden Vine"
        case .stainedGlass: return "Stained Glass"
        case .modernGlow: return "Modern Glow"
        }
    }
    
    /// Actual filename in Resources/Borders
    var filename: String {
        switch self {
        case .artDeco: return "template_01_art_deco_1770307365733"
        case .classicScroll: return "template_02_greek_laurel_1770307380099"
        case .sacredGeometry: return "template_03_sacred_geometry_1770307394997"
        case .celticKnot: return "template_04_celtic_knot_1770307423874"
        case .fleurDeLis: return "template_05_minimalist_1770307439021"
        case .baroque: return "template_06_baroque_1770307454492"
        case .victorian: return "template_07_victorian_1770307484325"
        case .goldenVine: return "template_08_islamic_1770307499223"
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
        
        // Draw reference if exists AND not already in content
        if let reference = reference, !content.contains(reference) {
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
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 1. Art Deco — INTRO POST STYLE: vine scrollwork corners
    // Matches the original Intro Post border exactly: thin double-line
    // rectangle with organic golden vine/scroll filigree at corners
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawArtDecoBorder() {
        let w = imageSize.width, h = imageSize.height
        
        // Thin outer frame
        strokeRect(NSRect(x: 30, y: 30, width: w-60, height: h-60), lineWidth: 2)
        // Inner frame
        strokeRect(NSRect(x: 50, y: 50, width: w-100, height: h-100), lineWidth: 1)
        
        // Corner vine scrollwork filigree at all 4 corners
        // Each corner gets multiple S-curve vines with leaves and curls
        let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (30, 30, 1, 1),       // bottom-left
            (w-30, 30, -1, 1),    // bottom-right
            (30, h-30, 1, -1),    // top-left
            (w-30, h-30, -1, -1)  // top-right
        ]
        for (ox, oy, dx, dy) in corners {
            drawVineCorner(at: NSPoint(x: ox, y: oy), dx: dx, dy: dy)
        }
        
        // Small flourish at edge midpoints
        let midX = w / 2, midY = h / 2
        for (mx, my, horizontal) in [(midX, CGFloat(30), true), (midX, h-30, true),
                                      (CGFloat(30), midY, false), (w-30, midY, false)] {
            drawEdgeFlourish(at: NSPoint(x: mx, y: my), horizontal: horizontal)
        }
    }
    
    /// Organic vine scrollwork for a single corner (Intro Post style)
    private func drawVineCorner(at o: NSPoint, dx: CGFloat, dy: CGFloat) {
        goldColor.setStroke()
        
        // Main vine — long S-curve extending along one edge
        let vine1 = NSBezierPath()
        vine1.move(to: NSPoint(x: o.x, y: o.y + dy * 10))
        vine1.curve(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 90),
                    controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 20),
                    controlPoint2: NSPoint(x: o.x - dx * 10, y: o.y + dy * 70))
        vine1.lineWidth = 2.5
        vine1.lineCapStyle = .round
        vine1.stroke()
        
        // Second vine — extends along the other edge
        let vine2 = NSBezierPath()
        vine2.move(to: NSPoint(x: o.x + dx * 10, y: o.y))
        vine2.curve(to: NSPoint(x: o.x + dx * 90, y: o.y + dy * 20),
                    controlPoint1: NSPoint(x: o.x + dx * 20, y: o.y + dy * 50),
                    controlPoint2: NSPoint(x: o.x + dx * 70, y: o.y - dy * 10))
        vine2.lineWidth = 2.5
        vine2.lineCapStyle = .round
        vine2.stroke()
        
        // Curling tendril off vine1
        let tendril1 = NSBezierPath()
        tendril1.move(to: NSPoint(x: o.x + dx * 15, y: o.y + dy * 50))
        tendril1.curve(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 65),
                       controlPoint1: NSPoint(x: o.x + dx * 40, y: o.y + dy * 35),
                       controlPoint2: NSPoint(x: o.x + dx * 55, y: o.y + dy * 55))
        tendril1.lineWidth = 1.8
        tendril1.stroke()
        
        // Spiral curl at tendril end
        let curl1 = NSBezierPath()
        let cEnd = NSPoint(x: o.x + dx * 50, y: o.y + dy * 65)
        curl1.move(to: cEnd)
        curl1.curve(to: NSPoint(x: cEnd.x + dx * 10, y: cEnd.y - dy * 6),
                    controlPoint1: NSPoint(x: cEnd.x + dx * 8, y: cEnd.y + dy * 8),
                    controlPoint2: NSPoint(x: cEnd.x + dx * 13, y: cEnd.y + dy * 2))
        curl1.lineWidth = 1.5
        curl1.stroke()
        
        // Curling tendril off vine2
        let tendril2 = NSBezierPath()
        tendril2.move(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 15))
        tendril2.curve(to: NSPoint(x: o.x + dx * 65, y: o.y + dy * 50),
                       controlPoint1: NSPoint(x: o.x + dx * 35, y: o.y + dy * 40),
                       controlPoint2: NSPoint(x: o.x + dx * 55, y: o.y + dy * 55))
        tendril2.lineWidth = 1.8
        tendril2.stroke()
        
        // Spiral curl at tendril2 end
        let curl2 = NSBezierPath()
        let cEnd2 = NSPoint(x: o.x + dx * 65, y: o.y + dy * 50)
        curl2.move(to: cEnd2)
        curl2.curve(to: NSPoint(x: cEnd2.x - dx * 6, y: cEnd2.y + dy * 10),
                    controlPoint1: NSPoint(x: cEnd2.x + dx * 8, y: cEnd2.y + dy * 8),
                    controlPoint2: NSPoint(x: cEnd2.x + dx * 2, y: cEnd2.y + dy * 13))
        curl2.lineWidth = 1.5
        curl2.stroke()
        
        // Leaf shapes along vines
        goldColor.setFill()
        drawLeaf(at: NSPoint(x: o.x + dx * 8, y: o.y + dy * 40), angle: atan2(dy, dx) + .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 40, y: o.y + dy * 8), angle: atan2(dy, dx) - .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 30, y: o.y + dy * 45), angle: atan2(dy, dx), size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 45, y: o.y + dy * 30), angle: atan2(dy, dx) + .pi/2, size: 6)
        
        // Tiny dots at vine intersections
        for (px, py) in [(o.x + dx*5, o.y + dy*25), (o.x + dx*25, o.y + dy*5),
                          (o.x + dx*35, o.y + dy*35)] {
            NSBezierPath(ovalIn: NSRect(x: px-2, y: py-2, width: 4, height: 4)).fill()
        }
    }
    
    /// Draw a small teardrop/leaf shape
    private func drawLeaf(at center: NSPoint, angle: CGFloat, size: CGFloat) {
        let path = NSBezierPath()
        let tip = NSPoint(x: center.x + size * cos(angle), y: center.y + size * sin(angle))
        let base = NSPoint(x: center.x - size * 0.3 * cos(angle), y: center.y - size * 0.3 * sin(angle))
        let perpAngle = angle + .pi / 2
        let cp1 = NSPoint(x: center.x + size * 0.6 * cos(perpAngle), y: center.y + size * 0.6 * sin(perpAngle))
        let cp2 = NSPoint(x: center.x - size * 0.6 * cos(perpAngle), y: center.y - size * 0.6 * sin(perpAngle))
        path.move(to: base)
        path.curve(to: tip, controlPoint1: cp1, controlPoint2: NSPoint(x: tip.x + size*0.2*cos(perpAngle), y: tip.y + size*0.2*sin(perpAngle)))
        path.curve(to: base, controlPoint1: NSPoint(x: tip.x - size*0.2*cos(perpAngle), y: tip.y - size*0.2*sin(perpAngle)), controlPoint2: cp2)
        path.fill()
    }
    
    /// Small flourish at edge midpoints
    private func drawEdgeFlourish(at p: NSPoint, horizontal: Bool) {
        let s: CGFloat = 15
        goldColor.setFill()
        fillDiamond(at: p, size: 5)
        goldColor.setStroke()
        if horizontal {
            let left = NSBezierPath()
            left.move(to: NSPoint(x: p.x - s, y: p.y))
            left.curve(to: NSPoint(x: p.x - s*2.5, y: p.y), controlPoint1: NSPoint(x: p.x - s*1.5, y: p.y + 8), controlPoint2: NSPoint(x: p.x - s*2, y: p.y + 5))
            left.lineWidth = 1.5
            left.stroke()
            let right = NSBezierPath()
            right.move(to: NSPoint(x: p.x + s, y: p.y))
            right.curve(to: NSPoint(x: p.x + s*2.5, y: p.y), controlPoint1: NSPoint(x: p.x + s*1.5, y: p.y - 8), controlPoint2: NSPoint(x: p.x + s*2, y: p.y - 5))
            right.lineWidth = 1.5
            right.stroke()
        } else {
            let up = NSBezierPath()
            up.move(to: NSPoint(x: p.x, y: p.y + s))
            up.curve(to: NSPoint(x: p.x, y: p.y + s*2.5), controlPoint1: NSPoint(x: p.x + 8, y: p.y + s*1.5), controlPoint2: NSPoint(x: p.x + 5, y: p.y + s*2))
            up.lineWidth = 1.5
            up.stroke()
            let down = NSBezierPath()
            down.move(to: NSPoint(x: p.x, y: p.y - s))
            down.curve(to: NSPoint(x: p.x, y: p.y - s*2.5), controlPoint1: NSPoint(x: p.x - 8, y: p.y - s*1.5), controlPoint2: NSPoint(x: p.x - 5, y: p.y - s*2))
            down.lineWidth = 1.5
            down.stroke()
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 2. Classic Scroll — INTRO POST MATCH
    // Thin rect + far-reaching scrollwork that extends deep along edges
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawClassicScrollBorder() {
        let w = imageSize.width, h = imageSize.height
        
        // Single thin rectangular border line
        strokeRect(NSRect(x: 35, y: 35, width: w-70, height: h-70), lineWidth: 1.5)
        
        // Far-reaching corner scrollwork at all 4 corners
        drawIntroCorner(at: NSPoint(x: 35, y: 35), dx: 1, dy: 1)
        drawIntroCorner(at: NSPoint(x: w-35, y: 35), dx: -1, dy: 1)
        drawIntroCorner(at: NSPoint(x: 35, y: h-35), dx: 1, dy: -1)
        drawIntroCorner(at: NSPoint(x: w-35, y: h-35), dx: -1, dy: -1)
    }
    
    /// Far-reaching scrollwork ornament (Intro Post style)
    /// Extends ~280px along each edge — "reaching" toward adjacent corners
    private func drawIntroCorner(at o: NSPoint, dx: CGFloat, dy: CGFloat) {
        goldColor.setStroke()
        goldColor.setFill()
        
        // ════════════════════════════════════════════
        // PRIMARY VINE along vertical edge (~280px long)
        // ════════════════════════════════════════════
        let pv = NSBezierPath()
        pv.move(to: NSPoint(x: o.x, y: o.y + dy * 5))
        pv.curve(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 280),
                 controlPoint1: NSPoint(x: o.x + dx * 55, y: o.y + dy * 60),
                 controlPoint2: NSPoint(x: o.x - dx * 25, y: o.y + dy * 200))
        pv.lineWidth = 2.5; pv.lineCapStyle = .round; pv.stroke()
        
        // ════════════════════════════════════════════
        // PRIMARY VINE along horizontal edge (~280px long)
        // ════════════════════════════════════════════
        let ph = NSBezierPath()
        ph.move(to: NSPoint(x: o.x + dx * 5, y: o.y))
        ph.curve(to: NSPoint(x: o.x + dx * 280, y: o.y + dy * 20),
                 controlPoint1: NSPoint(x: o.x + dx * 60, y: o.y + dy * 55),
                 controlPoint2: NSPoint(x: o.x + dx * 200, y: o.y - dy * 25))
        ph.lineWidth = 2.5; ph.lineCapStyle = .round; ph.stroke()
        
        // ════════════════════════════════════════════
        // DIAGONAL VINE from corner (~120px)
        // ════════════════════════════════════════════
        let dv = NSBezierPath()
        dv.move(to: NSPoint(x: o.x + dx * 3, y: o.y + dy * 3))
        dv.curve(to: NSPoint(x: o.x + dx * 100, y: o.y + dy * 100),
                 controlPoint1: NSPoint(x: o.x + dx * 65, y: o.y + dy * 10),
                 controlPoint2: NSPoint(x: o.x + dx * 10, y: o.y + dy * 65))
        dv.lineWidth = 2.5; dv.lineCapStyle = .round; dv.stroke()
        
        // Tight spiral at diagonal tip
        let ds = NSBezierPath()
        let dTip = NSPoint(x: o.x + dx * 100, y: o.y + dy * 100)
        ds.move(to: dTip)
        ds.curve(to: NSPoint(x: dTip.x - dx * 15, y: dTip.y - dy * 5),
                 controlPoint1: NSPoint(x: dTip.x + dx * 10, y: dTip.y - dy * 12),
                 controlPoint2: NSPoint(x: dTip.x - dx * 5, y: dTip.y - dy * 15))
        ds.lineWidth = 2; ds.stroke()
        
        // ════════════════════════════════════════════
        // SECONDARY VINE along vert edge (~200px, offset inward)
        // ════════════════════════════════════════════
        let sv = NSBezierPath()
        sv.move(to: NSPoint(x: o.x + dx * 10, y: o.y + dy * 20))
        sv.curve(to: NSPoint(x: o.x + dx * 35, y: o.y + dy * 200),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 50),
                 controlPoint2: NSPoint(x: o.x - dx * 10, y: o.y + dy * 150))
        sv.lineWidth = 2; sv.lineCapStyle = .round; sv.stroke()
        // Curl at end
        let svc = NSBezierPath()
        let svEnd = NSPoint(x: o.x + dx * 35, y: o.y + dy * 200)
        svc.move(to: svEnd)
        svc.curve(to: NSPoint(x: svEnd.x + dx * 12, y: svEnd.y - dy * 10),
                  controlPoint1: NSPoint(x: svEnd.x + dx * 15, y: svEnd.y + dy * 8),
                  controlPoint2: NSPoint(x: svEnd.x + dx * 16, y: svEnd.y - dy * 2))
        svc.lineWidth = 1.8; svc.stroke()
        
        // ════════════════════════════════════════════
        // SECONDARY VINE along horiz edge (~200px, offset inward)
        // ════════════════════════════════════════════
        let sh = NSBezierPath()
        sh.move(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 10))
        sh.curve(to: NSPoint(x: o.x + dx * 200, y: o.y + dy * 35),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 50),
                 controlPoint2: NSPoint(x: o.x + dx * 150, y: o.y - dy * 10))
        sh.lineWidth = 2; sh.lineCapStyle = .round; sh.stroke()
        // Curl at end
        let shc = NSBezierPath()
        let shEnd = NSPoint(x: o.x + dx * 200, y: o.y + dy * 35)
        shc.move(to: shEnd)
        shc.curve(to: NSPoint(x: shEnd.x - dx * 10, y: shEnd.y + dy * 12),
                  controlPoint1: NSPoint(x: shEnd.x + dx * 8, y: shEnd.y + dy * 15),
                  controlPoint2: NSPoint(x: shEnd.x - dx * 2, y: shEnd.y + dy * 16))
        shc.lineWidth = 1.8; shc.stroke()
        
        // ════════════════════════════════════════════
        // TERTIARY TENDRIL from vert vine (~160px)
        // ════════════════════════════════════════════
        let tv = NSBezierPath()
        tv.move(to: NSPoint(x: o.x + dx * 25, y: o.y + dy * 100))
        tv.curve(to: NSPoint(x: o.x + dx * 60, y: o.y + dy * 160),
                 controlPoint1: NSPoint(x: o.x + dx * 55, y: o.y + dy * 95),
                 controlPoint2: NSPoint(x: o.x + dx * 40, y: o.y + dy * 140))
        tv.lineWidth = 1.8; tv.stroke()
        // Curl
        let tvc = NSBezierPath()
        let tvEnd = NSPoint(x: o.x + dx * 60, y: o.y + dy * 160)
        tvc.move(to: tvEnd)
        tvc.curve(to: NSPoint(x: tvEnd.x + dx * 8, y: tvEnd.y - dy * 8),
                  controlPoint1: NSPoint(x: tvEnd.x + dx * 10, y: tvEnd.y + dy * 6),
                  controlPoint2: NSPoint(x: tvEnd.x + dx * 12, y: tvEnd.y - dy * 2))
        tvc.lineWidth = 1.5; tvc.stroke()
        
        // ════════════════════════════════════════════
        // TERTIARY TENDRIL from horiz vine (~160px)
        // ════════════════════════════════════════════
        let th = NSBezierPath()
        th.move(to: NSPoint(x: o.x + dx * 100, y: o.y + dy * 25))
        th.curve(to: NSPoint(x: o.x + dx * 160, y: o.y + dy * 60),
                 controlPoint1: NSPoint(x: o.x + dx * 95, y: o.y + dy * 55),
                 controlPoint2: NSPoint(x: o.x + dx * 140, y: o.y + dy * 40))
        th.lineWidth = 1.8; th.stroke()
        // Curl
        let thc = NSBezierPath()
        let thEnd = NSPoint(x: o.x + dx * 160, y: o.y + dy * 60)
        thc.move(to: thEnd)
        thc.curve(to: NSPoint(x: thEnd.x - dx * 8, y: thEnd.y + dy * 8),
                  controlPoint1: NSPoint(x: thEnd.x + dx * 6, y: thEnd.y + dy * 10),
                  controlPoint2: NSPoint(x: thEnd.x - dx * 2, y: thEnd.y + dy * 12))
        thc.lineWidth = 1.5; thc.stroke()
        
        // ════════════════════════════════════════════
        // OUTER TENDRIL off vert primary (~240px area)
        // ════════════════════════════════════════════
        let ov = NSBezierPath()
        ov.move(to: NSPoint(x: o.x + dx * 5, y: o.y + dy * 180))
        ov.curve(to: NSPoint(x: o.x + dx * 40, y: o.y + dy * 240),
                 controlPoint1: NSPoint(x: o.x + dx * 30, y: o.y + dy * 175),
                 controlPoint2: NSPoint(x: o.x + dx * 25, y: o.y + dy * 220))
        ov.lineWidth = 1.5; ov.stroke()
        let ovc = NSBezierPath()
        let ovEnd = NSPoint(x: o.x + dx * 40, y: o.y + dy * 240)
        ovc.move(to: ovEnd)
        ovc.curve(to: NSPoint(x: ovEnd.x + dx * 6, y: ovEnd.y - dy * 6),
                  controlPoint1: NSPoint(x: ovEnd.x + dx * 8, y: ovEnd.y + dy * 4),
                  controlPoint2: NSPoint(x: ovEnd.x + dx * 9, y: ovEnd.y - dy * 1))
        ovc.lineWidth = 1.3; ovc.stroke()
        
        // ════════════════════════════════════════════
        // OUTER TENDRIL off horiz primary (~240px area)
        // ════════════════════════════════════════════
        let oh = NSBezierPath()
        oh.move(to: NSPoint(x: o.x + dx * 180, y: o.y + dy * 5))
        oh.curve(to: NSPoint(x: o.x + dx * 240, y: o.y + dy * 40),
                 controlPoint1: NSPoint(x: o.x + dx * 175, y: o.y + dy * 30),
                 controlPoint2: NSPoint(x: o.x + dx * 220, y: o.y + dy * 25))
        oh.lineWidth = 1.5; oh.stroke()
        let ohc = NSBezierPath()
        let ohEnd = NSPoint(x: o.x + dx * 240, y: o.y + dy * 40)
        ohc.move(to: ohEnd)
        ohc.curve(to: NSPoint(x: ohEnd.x - dx * 6, y: ohEnd.y + dy * 6),
                  controlPoint1: NSPoint(x: ohEnd.x + dx * 4, y: ohEnd.y + dy * 8),
                  controlPoint2: NSPoint(x: ohEnd.x - dx * 1, y: ohEnd.y + dy * 9))
        ohc.lineWidth = 1.3; ohc.stroke()
        
        // ════════════════════════════════════════════
        // INNER CURLS between main and counter scrolls
        // ════════════════════════════════════════════
        let ic1 = NSBezierPath()
        ic1.move(to: NSPoint(x: o.x + dx * 30, y: o.y + dy * 20))
        ic1.curve(to: NSPoint(x: o.x + dx * 55, y: o.y + dy * 50),
                  controlPoint1: NSPoint(x: o.x + dx * 48, y: o.y + dy * 18),
                  controlPoint2: NSPoint(x: o.x + dx * 52, y: o.y + dy * 38))
        ic1.lineWidth = 2; ic1.stroke()
        
        let ic2 = NSBezierPath()
        ic2.move(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 30))
        ic2.curve(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 55),
                  controlPoint1: NSPoint(x: o.x + dx * 18, y: o.y + dy * 48),
                  controlPoint2: NSPoint(x: o.x + dx * 38, y: o.y + dy * 52))
        ic2.lineWidth = 2; ic2.stroke()
        
        // Small inner curl off diagonal
        let id1 = NSBezierPath()
        id1.move(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 50))
        id1.curve(to: NSPoint(x: o.x + dx * 70, y: o.y + dy * 40),
                  controlPoint1: NSPoint(x: o.x + dx * 60, y: o.y + dy * 55),
                  controlPoint2: NSPoint(x: o.x + dx * 65, y: o.y + dy * 42))
        id1.lineWidth = 1.5; id1.stroke()
        let id2 = NSBezierPath()
        id2.move(to: NSPoint(x: o.x + dx * 50, y: o.y + dy * 50))
        id2.curve(to: NSPoint(x: o.x + dx * 40, y: o.y + dy * 70),
                  controlPoint1: NSPoint(x: o.x + dx * 55, y: o.y + dy * 60),
                  controlPoint2: NSPoint(x: o.x + dx * 42, y: o.y + dy * 65))
        id2.lineWidth = 1.5; id2.stroke()
        
        // ════════════════════════════════════════════
        // LEAVES along all vines (distributed far)
        // ════════════════════════════════════════════
        // Along vertical primary
        drawLeaf(at: NSPoint(x: o.x + dx * 15, y: o.y + dy * 40), angle: atan2(dy, dx) + .pi/3, size: 9)
        drawLeaf(at: NSPoint(x: o.x + dx * 8, y: o.y + dy * 70), angle: atan2(dy, dx) - .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 20, y: o.y + dy * 110), angle: atan2(dy, dx) + .pi/5, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 10, y: o.y + dy * 150), angle: atan2(dy, dx) - .pi/3, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 18, y: o.y + dy * 195), angle: atan2(dy, dx) + .pi/6, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 15, y: o.y + dy * 240), angle: atan2(dy, dx) - .pi/4, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 20, y: o.y + dy * 265), angle: atan2(dy, dx) + .pi/3, size: 5)
        
        // Along horizontal primary
        drawLeaf(at: NSPoint(x: o.x + dx * 40, y: o.y + dy * 15), angle: atan2(dy, dx) - .pi/3, size: 9)
        drawLeaf(at: NSPoint(x: o.x + dx * 70, y: o.y + dy * 8), angle: atan2(dy, dx) + .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 110, y: o.y + dy * 20), angle: atan2(dy, dx) - .pi/5, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 150, y: o.y + dy * 10), angle: atan2(dy, dx) + .pi/3, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 195, y: o.y + dy * 18), angle: atan2(dy, dx) - .pi/6, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 240, y: o.y + dy * 15), angle: atan2(dy, dx) + .pi/4, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 265, y: o.y + dy * 20), angle: atan2(dy, dx) - .pi/3, size: 5)
        
        // Along diagonal
        drawLeaf(at: NSPoint(x: o.x + dx * 30, y: o.y + dy * 28), angle: atan2(dy, dx), size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 60, y: o.y + dy * 55), angle: atan2(dy, dx) + .pi/2, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 85, y: o.y + dy * 88), angle: atan2(dy, dx) - .pi/4, size: 7)
        
        // Along tendrils
        drawLeaf(at: NSPoint(x: o.x + dx * 45, y: o.y + dy * 130), angle: .pi/3, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 130, y: o.y + dy * 45), angle: -.pi/3, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 30, y: o.y + dy * 215), angle: .pi/4, size: 5)
        drawLeaf(at: NSPoint(x: o.x + dx * 215, y: o.y + dy * 30), angle: -.pi/4, size: 5)
        
        // ════════════════════════════════════════════
        // DECORATIVE DOTS along vine paths
        // ════════════════════════════════════════════
        let dotPositions: [(CGFloat, CGFloat)] = [
            (8, 25), (25, 8), (15, 15), (40, 40),
            (60, 60), (80, 80), (35, 55), (55, 35),
            (10, 90), (90, 10), (5, 130), (130, 5),
            (15, 170), (170, 15), (10, 210), (210, 10),
            (18, 250), (250, 18), (45, 100), (100, 45)
        ]
        for (px, py) in dotPositions {
            NSBezierPath(ovalIn: NSRect(x: o.x + dx*px - 2, y: o.y + dy*py - 2, width: 4, height: 4)).fill()
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 3. Sacred Geometry — Flower of Life (OVAL frame)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawSacredGeometryBorder() {
        let w = imageSize.width, h = imageSize.height
        
        // Flower of Life cluster at cardinal points and corners
        let circR: CGFloat = 16
        let positions: [(CGFloat, CGFloat)] = [
            (w/2, 35), (w/2, h-35), (35, h/2), (w-35, h/2),
            (80, 80), (w-80, 80), (80, h-80), (w-80, h-80)
        ]
        goldColor.setStroke()
        for (cx, cy) in positions {
            strokeOval(center: NSPoint(x: cx, y: cy), radius: circR, lineWidth: 1.2)
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3
                strokeOval(center: NSPoint(x: cx + circR * cos(a), y: cy + circR * sin(a)),
                          radius: circR, lineWidth: 0.8)
            }
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 4. Celtic Knot — Woven interlace with knot corners
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawCelticKnotBorder() {
        let w = imageSize.width, h = imageSize.height
        
        // Triple frame with ROUNDED corners
        for (inset, lw, radius): (CGFloat, CGFloat, CGFloat) in [(25, 3, 20), (40, 1.5, 14), (55, 3, 8)] {
            let rect = NSRect(x: inset, y: inset, width: w-inset*2, height: h-inset*2)
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            path.lineWidth = lw
            path.stroke()
        }
        
        // Woven figure-eight knots at each corner
        let ki: CGFloat = 40
        for (cx, cy) in [(ki, ki), (w-ki, ki), (ki, h-ki), (w-ki, h-ki)] {
            let knotR: CGFloat = 18
            let o1 = NSBezierPath(ovalIn: NSRect(x: cx-knotR, y: cy-knotR/2, width: knotR*2, height: knotR))
            o1.lineWidth = 2.5; o1.stroke()
            let o2 = NSBezierPath(ovalIn: NSRect(x: cx-knotR/2, y: cy-knotR, width: knotR, height: knotR*2))
            o2.lineWidth = 2.5; o2.stroke()
            goldColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: cx-4, y: cy-4, width: 8, height: 8)).fill()
        }
        
        // Interlace knot crossings along edges
        let step: CGFloat = 55
        for x in stride(from: ki + step, to: w - ki, by: step) {
            drawKnotCross(at: NSPoint(x: x, y: 40))
            drawKnotCross(at: NSPoint(x: x, y: h - 40))
        }
        for y in stride(from: ki + step, to: h - ki, by: step) {
            drawKnotCross(at: NSPoint(x: 40, y: y))
            drawKnotCross(at: NSPoint(x: w - 40, y: y))
        }
    }
    
    private func drawKnotCross(at p: NSPoint) {
        let s: CGFloat = 10
        let path = NSBezierPath()
        path.move(to: NSPoint(x: p.x-s, y: p.y)); path.line(to: NSPoint(x: p.x+s, y: p.y))
        path.move(to: NSPoint(x: p.x, y: p.y-s)); path.line(to: NSPoint(x: p.x, y: p.y+s))
        path.lineWidth = 2; path.stroke()
        for (dx, dy) in [(-s, CGFloat(0)), (s, CGFloat(0)), (CGFloat(0), -s), (CGFloat(0), s)] {
            let oval = NSBezierPath(ovalIn: NSRect(x: p.x+dx-3, y: p.y+dy-3, width: 6, height: 6))
            oval.lineWidth = 1; oval.stroke()
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 5. Fleur-de-lis — Classic heraldic lily motifs
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawFleurDeLisBorder() {
        let w = imageSize.width, h = imageSize.height
        
        // Elegant rounded double frame
        let outer = NSBezierPath(roundedRect: NSRect(x: 25, y: 25, width: w-50, height: h-50), xRadius: 18, yRadius: 18)
        outer.lineWidth = 3; outer.stroke()
        let inner = NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: w-100, height: h-100), xRadius: 10, yRadius: 10)
        inner.lineWidth = 1.5; inner.stroke()
        
        // Fleur-de-lis at all 4 corners (larger, 28pt)
        drawFleurDeLis(at: NSPoint(x: 38, y: 38), size: 28, angle: .pi/4)
        drawFleurDeLis(at: NSPoint(x: w-38, y: 38), size: 28, angle: 3 * .pi/4)
        drawFleurDeLis(at: NSPoint(x: 38, y: h-38), size: 28, angle: -.pi/4)
        drawFleurDeLis(at: NSPoint(x: w-38, y: h-38), size: 28, angle: -3 * .pi/4)
        
        // Fleur-de-lis at edge midpoints (medium, 22pt)
        drawFleurDeLis(at: NSPoint(x: w/2, y: 32), size: 22, angle: 0)
        drawFleurDeLis(at: NSPoint(x: w/2, y: h-32), size: 22, angle: .pi)
        drawFleurDeLis(at: NSPoint(x: 32, y: h/2), size: 22, angle: -.pi/2)
        drawFleurDeLis(at: NSPoint(x: w-32, y: h/2), size: 22, angle: .pi/2)
        
        // Small fleur-de-lis spaced along edges
        let step: CGFloat = 100
        for x in stride(from: CGFloat(120), to: w/2 - 40, by: step) {
            drawFleurDeLis(at: NSPoint(x: x, y: 37), size: 14, angle: 0)
            drawFleurDeLis(at: NSPoint(x: w-x, y: 37), size: 14, angle: 0)
            drawFleurDeLis(at: NSPoint(x: x, y: h-37), size: 14, angle: .pi)
            drawFleurDeLis(at: NSPoint(x: w-x, y: h-37), size: 14, angle: .pi)
        }
        for y in stride(from: CGFloat(120), to: h/2 - 40, by: step) {
            drawFleurDeLis(at: NSPoint(x: 37, y: y), size: 14, angle: -.pi/2)
            drawFleurDeLis(at: NSPoint(x: 37, y: h-y), size: 14, angle: -.pi/2)
            drawFleurDeLis(at: NSPoint(x: w-37, y: y), size: 14, angle: .pi/2)
            drawFleurDeLis(at: NSPoint(x: w-37, y: h-y), size: 14, angle: .pi/2)
        }
    }
    
    /// Draw a single fleur-de-lis motif at the given center, size, and rotation
    private func drawFleurDeLis(at center: NSPoint, size: CGFloat, angle: CGFloat) {
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle)
        
        goldColor.setStroke()
        goldColor.setFill()
        
        // Center petal (tall, pointed)
        let cp = NSBezierPath()
        cp.move(to: NSPoint(x: 0, y: -size * 0.15))
        cp.curve(to: NSPoint(x: 0, y: size * 0.9),
                 controlPoint1: NSPoint(x: -size * 0.25, y: size * 0.3),
                 controlPoint2: NSPoint(x: -size * 0.1, y: size * 0.7))
        cp.curve(to: NSPoint(x: 0, y: -size * 0.15),
                 controlPoint1: NSPoint(x: size * 0.1, y: size * 0.7),
                 controlPoint2: NSPoint(x: size * 0.25, y: size * 0.3))
        cp.fill()
        
        // Left petal (curved outward)
        let lp = NSBezierPath()
        lp.move(to: NSPoint(x: 0, y: size * 0.1))
        lp.curve(to: NSPoint(x: -size * 0.55, y: size * 0.7),
                 controlPoint1: NSPoint(x: -size * 0.15, y: size * 0.4),
                 controlPoint2: NSPoint(x: -size * 0.6, y: size * 0.45))
        lp.curve(to: NSPoint(x: -size * 0.1, y: size * 0.35),
                 controlPoint1: NSPoint(x: -size * 0.45, y: size * 0.75),
                 controlPoint2: NSPoint(x: -size * 0.2, y: size * 0.55))
        lp.fill()
        
        // Right petal (mirror of left)
        let rp = NSBezierPath()
        rp.move(to: NSPoint(x: 0, y: size * 0.1))
        rp.curve(to: NSPoint(x: size * 0.55, y: size * 0.7),
                 controlPoint1: NSPoint(x: size * 0.15, y: size * 0.4),
                 controlPoint2: NSPoint(x: size * 0.6, y: size * 0.45))
        rp.curve(to: NSPoint(x: size * 0.1, y: size * 0.35),
                 controlPoint1: NSPoint(x: size * 0.45, y: size * 0.75),
                 controlPoint2: NSPoint(x: size * 0.2, y: size * 0.55))
        rp.fill()
        
        // Horizontal band across the base
        let band = NSBezierPath(rect: NSRect(x: -size * 0.28, y: -size * 0.05, width: size * 0.56, height: size * 0.12))
        band.fill()
        
        // Stem below band
        let stem = NSBezierPath(rect: NSRect(x: -size * 0.06, y: -size * 0.35, width: size * 0.12, height: size * 0.32))
        stem.fill()
        
        // Base flare
        let base = NSBezierPath()
        base.move(to: NSPoint(x: -size * 0.2, y: -size * 0.35))
        base.line(to: NSPoint(x: size * 0.2, y: -size * 0.35))
        base.line(to: NSPoint(x: size * 0.15, y: -size * 0.42))
        base.line(to: NSPoint(x: -size * 0.15, y: -size * 0.42))
        base.close()
        base.fill()
        
        ctx.restoreGState()
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 6. Baroque — Scrollwork filigree (curved frame)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawBaroqueBorder() {
        let w = imageSize.width, h = imageSize.height
        
        // CURVED outer frame
        let outer = NSBezierPath(roundedRect: NSRect(x: 18, y: 18, width: w-36, height: h-36), xRadius: 24, yRadius: 24)
        outer.lineWidth = 5
        outer.stroke()
        // Inner frame
        let inner = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: w-104, height: h-104), xRadius: 12, yRadius: 12)
        inner.lineWidth = 1.5
        inner.stroke()
        
        // Elaborate scrollwork filigree at each corner
        for (cx, cy, flipX, flipY) in [(CGFloat(18), CGFloat(18), false, false),
                                         (w-18, CGFloat(18), true, false),
                                         (CGFloat(18), h-18, false, true),
                                         (w-18, h-18, true, true)] {
            drawFiligreeScroll(at: NSPoint(x: cx, y: cy), flipX: flipX, flipY: flipY)
        }
        
        // Running dot+ring ornament along edges
        let step: CGFloat = 45
        let outerR = NSRect(x: 18, y: 18, width: w-36, height: h-36)
        for x in stride(from: outerR.minX + 80, to: outerR.maxX - 60, by: step) {
            drawOrnamentDot(at: NSPoint(x: x, y: outerR.minY))
            drawOrnamentDot(at: NSPoint(x: x, y: outerR.maxY))
        }
        for y in stride(from: outerR.minY + 80, to: outerR.maxY - 60, by: step) {
            drawOrnamentDot(at: NSPoint(x: outerR.minX, y: y))
            drawOrnamentDot(at: NSPoint(x: outerR.maxX, y: y))
        }
    }
    
    private func drawFiligreeScroll(at origin: NSPoint, flipX: Bool, flipY: Bool) {
        let dx: CGFloat = flipX ? -1 : 1
        let dy: CGFloat = flipY ? -1 : 1
        
        let s1 = NSBezierPath()
        s1.move(to: NSPoint(x: origin.x, y: origin.y + dy * 30))
        s1.curve(to: NSPoint(x: origin.x + dx * 55, y: origin.y + dy * 65),
                 controlPoint1: NSPoint(x: origin.x + dx * 40, y: origin.y + dy * 10),
                 controlPoint2: NSPoint(x: origin.x + dx * 18, y: origin.y + dy * 60))
        s1.lineWidth = 2.5; s1.stroke()
        
        let s2 = NSBezierPath()
        s2.move(to: NSPoint(x: origin.x + dx * 30, y: origin.y))
        s2.curve(to: NSPoint(x: origin.x + dx * 65, y: origin.y + dy * 55),
                 controlPoint1: NSPoint(x: origin.x + dx * 10, y: origin.y + dy * 40),
                 controlPoint2: NSPoint(x: origin.x + dx * 60, y: origin.y + dy * 18))
        s2.lineWidth = 2; s2.stroke()
        
        let curl = NSBezierPath()
        let ce = NSPoint(x: origin.x + dx * 55, y: origin.y + dy * 65)
        curl.move(to: ce)
        curl.curve(to: NSPoint(x: ce.x + dx*15, y: ce.y - dy*8),
                   controlPoint1: NSPoint(x: ce.x + dx*12, y: ce.y + dy*10),
                   controlPoint2: NSPoint(x: ce.x + dx*18, y: ce.y + dy*2))
        curl.lineWidth = 2; curl.stroke()
        
        let curl2 = NSBezierPath()
        let ce2 = NSPoint(x: origin.x + dx * 65, y: origin.y + dy * 55)
        curl2.move(to: ce2)
        curl2.curve(to: NSPoint(x: ce2.x - dx*8, y: ce2.y + dy*15),
                    controlPoint1: NSPoint(x: ce2.x + dx*10, y: ce2.y + dy*12),
                    controlPoint2: NSPoint(x: ce2.x + dx*2, y: ce2.y + dy*18))
        curl2.lineWidth = 1.5; curl2.stroke()
        
        goldColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: origin.x + dx*24-4, y: origin.y + dy*24-5, width: 8, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: origin.x + dx*40-3, y: origin.y + dy*40-4, width: 6, height: 8)).fill()
    }
    
    private func drawOrnamentDot(at p: NSPoint) {
        goldColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x-3, y: p.y-3, width: 6, height: 6)).fill()
        let ring = NSBezierPath(ovalIn: NSRect(x: p.x-8, y: p.y-8, width: 16, height: 16))
        ring.lineWidth = 1; ring.stroke()
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 7. Victorian — Corner flourishes + flower ornaments
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawVictorianBorder() {
        let w = imageSize.width, h = imageSize.height
        
        let outer = NSRect(x: 22, y: 22, width: w-44, height: h-44)
        NSBezierPath(roundedRect: outer, xRadius: 20, yRadius: 20).apply { $0.lineWidth = 4; $0.stroke() }
        let inner = NSRect(x: 50, y: 50, width: w-100, height: h-100)
        NSBezierPath(roundedRect: inner, xRadius: 14, yRadius: 14).apply { $0.lineWidth = 2; $0.stroke() }
        
        let ci: CGFloat = 36
        let fR: CGFloat = 50
        for (cx, cy, sa, ea) in [(ci, ci, CGFloat(0), CGFloat(90)),
                                   (w-ci, ci, CGFloat(90), CGFloat(180)),
                                   (w-ci, h-ci, CGFloat(180), CGFloat(270)),
                                   (ci, h-ci, CGFloat(270), CGFloat(360))] {
            for (r, lw) in [(fR, CGFloat(2.5)), (fR*0.55, CGFloat(1.5)), (fR*0.3, CGFloat(1))] {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: r, startAngle: sa, endAngle: ea)
                arc.lineWidth = lw; arc.stroke()
            }
            let midAngle = (sa + ea) / 2 * .pi / 180
            goldColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: cx + fR*0.7*cos(midAngle) - 5,
                                        y: cy + fR*0.7*sin(midAngle) - 5, width: 10, height: 10)).fill()
        }
        
        let step: CGFloat = 65
        for x in stride(from: outer.minX + 60, to: outer.maxX - 40, by: step) {
            drawSmallFlower(at: NSPoint(x: x, y: outer.minY + 14))
            drawSmallFlower(at: NSPoint(x: x, y: outer.maxY - 14))
        }
    }
    
    private func drawSmallFlower(at p: NSPoint) {
        for i in 0..<4 {
            let a = CGFloat(i) * .pi / 2
            let petal = NSBezierPath(ovalIn: NSRect(x: p.x + 5*cos(a) - 3, y: p.y + 5*sin(a) - 3, width: 6, height: 6))
            petal.lineWidth = 1; petal.stroke()
        }
        goldColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x-2.5, y: p.y-2.5, width: 5, height: 5)).fill()
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 8. Golden Vine — Intro Post style: lush corner scrollwork
    // Exact match: thin double-line rect + elaborate organic vine filigree
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawGoldenVineBorder() {
        let w = imageSize.width, h = imageSize.height
        
        // Thin double-line rectangular frame (matches intro post exactly)
        strokeRect(NSRect(x: 28, y: 28, width: w-56, height: h-56), lineWidth: 2)
        strokeRect(NSRect(x: 42, y: 42, width: w-84, height: h-84), lineWidth: 1)
        
        // Elaborate vine scrollwork at all 4 corners
        // These are MUCH more lush than Art Deco — longer vines, more leaves, more curls
        drawLushVineCorner(at: NSPoint(x: 28, y: 28), dx: 1, dy: 1)
        drawLushVineCorner(at: NSPoint(x: w-28, y: 28), dx: -1, dy: 1)
        drawLushVineCorner(at: NSPoint(x: 28, y: h-28), dx: 1, dy: -1)
        drawLushVineCorner(at: NSPoint(x: w-28, y: h-28), dx: -1, dy: -1)
    }
    
    /// Draw elaborate lush vine scrollwork for one corner (Intro Post style)
    /// Much more ornate than Art Deco — vines extend ~140px, many leaves & curls
    private func drawLushVineCorner(at o: NSPoint, dx: CGFloat, dy: CGFloat) {
        goldColor.setStroke()
        goldColor.setFill()
        
        // ── PRIMARY VINE: long S-curve extending along vertical edge ──
        let v1 = NSBezierPath()
        v1.move(to: NSPoint(x: o.x, y: o.y + dy * 8))
        v1.curve(to: NSPoint(x: o.x + dx * 15, y: o.y + dy * 140),
                 controlPoint1: NSPoint(x: o.x + dx * 55, y: o.y + dy * 30),
                 controlPoint2: NSPoint(x: o.x - dx * 20, y: o.y + dy * 110))
        v1.lineWidth = 2.5; v1.lineCapStyle = .round; v1.stroke()
        
        // ── PRIMARY VINE: long S-curve extending along horizontal edge ──
        let v2 = NSBezierPath()
        v2.move(to: NSPoint(x: o.x + dx * 8, y: o.y))
        v2.curve(to: NSPoint(x: o.x + dx * 140, y: o.y + dy * 15),
                 controlPoint1: NSPoint(x: o.x + dx * 30, y: o.y + dy * 55),
                 controlPoint2: NSPoint(x: o.x + dx * 110, y: o.y - dy * 20))
        v2.lineWidth = 2.5; v2.lineCapStyle = .round; v2.stroke()
        
        // ── DIAGONAL VINE from corner ──
        let vd = NSBezierPath()
        vd.move(to: NSPoint(x: o.x + dx * 5, y: o.y + dy * 5))
        vd.curve(to: NSPoint(x: o.x + dx * 80, y: o.y + dy * 80),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 15),
                 controlPoint2: NSPoint(x: o.x + dx * 15, y: o.y + dy * 50))
        vd.lineWidth = 2; vd.lineCapStyle = .round; vd.stroke()
        
        // ── SECONDARY TENDRIL off vertical vine ──
        let t1 = NSBezierPath()
        t1.move(to: NSPoint(x: o.x + dx * 20, y: o.y + dy * 60))
        t1.curve(to: NSPoint(x: o.x + dx * 65, y: o.y + dy * 85),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 45),
                 controlPoint2: NSPoint(x: o.x + dx * 60, y: o.y + dy * 70))
        t1.lineWidth = 1.8; t1.stroke()
        
        // Spiral curl at tendril end
        let c1 = NSBezierPath()
        let ce1 = NSPoint(x: o.x + dx * 65, y: o.y + dy * 85)
        c1.move(to: ce1)
        c1.curve(to: NSPoint(x: ce1.x + dx * 12, y: ce1.y - dy * 8),
                 controlPoint1: NSPoint(x: ce1.x + dx * 10, y: ce1.y + dy * 10),
                 controlPoint2: NSPoint(x: ce1.x + dx * 15, y: ce1.y + dy * 2))
        c1.lineWidth = 1.5; c1.stroke()
        
        // ── SECONDARY TENDRIL off horizontal vine ──
        let t2 = NSBezierPath()
        t2.move(to: NSPoint(x: o.x + dx * 60, y: o.y + dy * 20))
        t2.curve(to: NSPoint(x: o.x + dx * 85, y: o.y + dy * 65),
                 controlPoint1: NSPoint(x: o.x + dx * 45, y: o.y + dy * 50),
                 controlPoint2: NSPoint(x: o.x + dx * 70, y: o.y + dy * 60))
        t2.lineWidth = 1.8; t2.stroke()
        
        // Spiral curl at tendril2 end
        let c2 = NSBezierPath()
        let ce2 = NSPoint(x: o.x + dx * 85, y: o.y + dy * 65)
        c2.move(to: ce2)
        c2.curve(to: NSPoint(x: ce2.x - dx * 8, y: ce2.y + dy * 12),
                 controlPoint1: NSPoint(x: ce2.x + dx * 10, y: ce2.y + dy * 10),
                 controlPoint2: NSPoint(x: ce2.x + dx * 2, y: ce2.y + dy * 15))
        c2.lineWidth = 1.5; c2.stroke()
        
        // ── OUTER TENDRIL off vertical vine (further out) ──
        let t3 = NSBezierPath()
        t3.move(to: NSPoint(x: o.x + dx * 5, y: o.y + dy * 100))
        t3.curve(to: NSPoint(x: o.x + dx * 45, y: o.y + dy * 120),
                 controlPoint1: NSPoint(x: o.x + dx * 30, y: o.y + dy * 90),
                 controlPoint2: NSPoint(x: o.x + dx * 40, y: o.y + dy * 105))
        t3.lineWidth = 1.5; t3.stroke()
        // Curl
        let c3 = NSBezierPath()
        let ce3 = NSPoint(x: o.x + dx * 45, y: o.y + dy * 120)
        c3.move(to: ce3)
        c3.curve(to: NSPoint(x: ce3.x + dx * 8, y: ce3.y - dy * 5),
                 controlPoint1: NSPoint(x: ce3.x + dx * 6, y: ce3.y + dy * 6),
                 controlPoint2: NSPoint(x: ce3.x + dx * 10, y: ce3.y + dy * 1))
        c3.lineWidth = 1.2; c3.stroke()
        
        // ── OUTER TENDRIL off horizontal vine ──
        let t4 = NSBezierPath()
        t4.move(to: NSPoint(x: o.x + dx * 100, y: o.y + dy * 5))
        t4.curve(to: NSPoint(x: o.x + dx * 120, y: o.y + dy * 45),
                 controlPoint1: NSPoint(x: o.x + dx * 90, y: o.y + dy * 30),
                 controlPoint2: NSPoint(x: o.x + dx * 105, y: o.y + dy * 40))
        t4.lineWidth = 1.5; t4.stroke()
        // Curl
        let c4 = NSBezierPath()
        let ce4 = NSPoint(x: o.x + dx * 120, y: o.y + dy * 45)
        c4.move(to: ce4)
        c4.curve(to: NSPoint(x: ce4.x - dx * 5, y: ce4.y + dy * 8),
                 controlPoint1: NSPoint(x: ce4.x + dx * 6, y: ce4.y + dy * 6),
                 controlPoint2: NSPoint(x: ce4.x + dx * 1, y: ce4.y + dy * 10))
        c4.lineWidth = 1.2; c4.stroke()
        
        // ── TINY INWARD CURL from diagonal vine ──
        let ti = NSBezierPath()
        ti.move(to: NSPoint(x: o.x + dx * 40, y: o.y + dy * 40))
        ti.curve(to: NSPoint(x: o.x + dx * 60, y: o.y + dy * 30),
                 controlPoint1: NSPoint(x: o.x + dx * 50, y: o.y + dy * 48),
                 controlPoint2: NSPoint(x: o.x + dx * 55, y: o.y + dy * 35))
        ti.lineWidth = 1.3; ti.stroke()
        
        let ti2 = NSBezierPath()
        ti2.move(to: NSPoint(x: o.x + dx * 40, y: o.y + dy * 40))
        ti2.curve(to: NSPoint(x: o.x + dx * 30, y: o.y + dy * 60),
                  controlPoint1: NSPoint(x: o.x + dx * 48, y: o.y + dy * 50),
                  controlPoint2: NSPoint(x: o.x + dx * 35, y: o.y + dy * 55))
        ti2.lineWidth = 1.3; ti2.stroke()
        
        // ── LEAVES along all vines ──
        // Along vertical vine
        drawLeaf(at: NSPoint(x: o.x + dx * 12, y: o.y + dy * 35), angle: atan2(dy, dx) + .pi/3, size: 9)
        drawLeaf(at: NSPoint(x: o.x + dx * 5, y: o.y + dy * 55), angle: atan2(dy, dx) - .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 10, y: o.y + dy * 80), angle: atan2(dy, dx) + .pi/5, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 12, y: o.y + dy * 115), angle: atan2(dy, dx) - .pi/3, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 8, y: o.y + dy * 130), angle: atan2(dy, dx) + .pi/6, size: 6)
        
        // Along horizontal vine
        drawLeaf(at: NSPoint(x: o.x + dx * 35, y: o.y + dy * 12), angle: atan2(dy, dx) - .pi/3, size: 9)
        drawLeaf(at: NSPoint(x: o.x + dx * 55, y: o.y + dy * 5), angle: atan2(dy, dx) + .pi/4, size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 80, y: o.y + dy * 10), angle: atan2(dy, dx) - .pi/5, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 115, y: o.y + dy * 12), angle: atan2(dy, dx) + .pi/3, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 130, y: o.y + dy * 8), angle: atan2(dy, dx) - .pi/6, size: 6)
        
        // Along diagonal vine
        drawLeaf(at: NSPoint(x: o.x + dx * 25, y: o.y + dy * 22), angle: atan2(dy, dx), size: 8)
        drawLeaf(at: NSPoint(x: o.x + dx * 50, y: o.y + dy * 48), angle: atan2(dy, dx) + .pi/2, size: 7)
        drawLeaf(at: NSPoint(x: o.x + dx * 68, y: o.y + dy * 72), angle: atan2(dy, dx) - .pi/4, size: 6)
        
        // Along tendrils
        drawLeaf(at: NSPoint(x: o.x + dx * 40, y: o.y + dy * 70), angle: .pi/3, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 70, y: o.y + dy * 40), angle: -.pi/3, size: 6)
        drawLeaf(at: NSPoint(x: o.x + dx * 30, y: o.y + dy * 108), angle: .pi/4, size: 5)
        drawLeaf(at: NSPoint(x: o.x + dx * 108, y: o.y + dy * 30), angle: -.pi/4, size: 5)
        
        // ── DOTS at vine intersections and along vines ──
        let dotPositions: [(CGFloat, CGFloat)] = [
            (5, 20), (20, 5), (15, 45), (45, 15),
            (30, 30), (55, 55), (70, 70),
            (10, 70), (70, 10), (5, 95), (95, 5),
            (10, 125), (125, 10), (50, 80), (80, 50)
        ]
        for (px, py) in dotPositions {
            NSBezierPath(ovalIn: NSRect(x: o.x + dx*px - 2, y: o.y + dy*py - 2, width: 4, height: 4)).fill()
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 9. Stained Glass — Cathedral arch + radial mullions
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawStainedGlassBorder() {
        let w = imageSize.width, h = imageSize.height
        let archR = (w - 60) / 2
        let archCY = h - 60 - archR
        
        let outer = NSBezierPath()
        outer.move(to: NSPoint(x: 30, y: 60))
        outer.line(to: NSPoint(x: 30, y: archCY))
        outer.appendArc(withCenter: NSPoint(x: w/2, y: archCY), radius: archR, startAngle: 180, endAngle: 0)
        outer.line(to: NSPoint(x: w-30, y: 60))
        outer.close()
        outer.lineWidth = 4; outer.stroke()
        
        let innerR = archR - 22
        let innerFrame = NSBezierPath()
        innerFrame.move(to: NSPoint(x: 52, y: 72))
        innerFrame.line(to: NSPoint(x: 52, y: archCY))
        innerFrame.appendArc(withCenter: NSPoint(x: w/2, y: archCY), radius: innerR, startAngle: 180, endAngle: 0)
        innerFrame.line(to: NSPoint(x: w-52, y: 72))
        innerFrame.close()
        innerFrame.lineWidth = 2; innerFrame.stroke()
        
        goldColor.withAlphaComponent(0.4).setStroke()
        let ac = NSPoint(x: w/2, y: archCY)
        for i in 1..<8 {
            let angle = CGFloat(i) * .pi / 8
            let line = NSBezierPath()
            line.move(to: NSPoint(x: ac.x + innerR*cos(angle), y: ac.y + innerR*sin(angle)))
            line.line(to: NSPoint(x: ac.x + archR*cos(angle), y: ac.y + archR*sin(angle)))
            line.lineWidth = 1.5; line.stroke()
        }
        for r in stride(from: innerR + 30, to: archR, by: 30) {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: ac, radius: r, startAngle: 15, endAngle: 165)
            arc.lineWidth = 1; arc.stroke()
        }
        goldColor.setStroke()
        goldColor.setFill()
        NSBezierPath(rect: NSRect(x: 30, y: 52, width: w-60, height: 5)).fill()
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - 10. Modern Glow — Layered luminous aura
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawModernGlowBorder() {
        let w = imageSize.width, h = imageSize.height
        
        for i in (0..<8).reversed() {
            let inset = CGFloat(12 + i * 6)
            let alpha = 0.08 + (1.0 - Double(i) / 7.0) * 0.92
            let lw = CGFloat(1 + (7 - i))
            NSColor(red: 212/255, green: 175/255, blue: 55/255, alpha: CGFloat(alpha)).setStroke()
            let path = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: w-inset*2, height: h-inset*2),
                                     xRadius: 8, yRadius: 8)
            path.lineWidth = lw; path.stroke()
        }
        
        goldColor.setStroke()
        let inner = NSRect(x: 58, y: 58, width: w-116, height: h-116)
        let innerPath = NSBezierPath(roundedRect: inner, xRadius: 4, yRadius: 4)
        innerPath.lineWidth = 2; innerPath.stroke()
        
        for (cx, cy) in [(inner.minX, inner.minY), (inner.maxX, inner.minY),
                          (inner.minX, inner.maxY), (inner.maxX, inner.maxY)] {
            for (r, a) in [(CGFloat(14), CGFloat(0.1)), (CGFloat(9), CGFloat(0.3)),
                           (CGFloat(5), CGFloat(0.7)), (CGFloat(2.5), CGFloat(1.0))] {
                NSColor(red: 212/255, green: 175/255, blue: 55/255, alpha: a).setFill()
                NSBezierPath(ovalIn: NSRect(x: cx-r, y: cy-r, width: r*2, height: r*2)).fill()
            }
        }
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Drawing Helpers
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func strokeRect(_ rect: NSRect, lineWidth: CGFloat) {
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }
    
    private func strokeOval(center: NSPoint, radius: CGFloat, lineWidth: CGFloat) {
        let oval = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                                width: radius*2, height: radius*2))
        oval.lineWidth = lineWidth
        oval.stroke()
    }
    
    private func fillDiamond(at p: NSPoint, size: CGFloat) {
        let d = NSBezierPath()
        d.move(to: NSPoint(x: p.x, y: p.y - size))
        d.line(to: NSPoint(x: p.x + size, y: p.y))
        d.line(to: NSPoint(x: p.x, y: p.y + size))
        d.line(to: NSPoint(x: p.x - size, y: p.y))
        d.close()
        d.fill()
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Adaptive Text Filling Algorithm
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    /// Smart text formatter that breaks content into readable lines.
    /// Priority: sentence breaks > clause breaks > phrase breaks > word wrap.
    /// The goal is to maximise font size by distributing text across more lines.
    private func formatContentForDisplay(_ text: String, targetWidth: CGFloat, fontSize: CGFloat) -> String {
        // First apply sentence-level breaks
        var result = text
        
        // Break after periods (sentence ends)
        result = result.replacingOccurrences(of: ". ", with: ".\n")
        // Break after semicolons
        result = result.replacingOccurrences(of: "; ", with: ";\n")
        // Break after colons followed by uppercase
        result = result.replacingOccurrences(of: ":\\s+([A-Z])", with: ":\n$1", options: .regularExpression)
        // Break after question marks and exclamation marks
        result = result.replacingOccurrences(of: "? ", with: "?\n")
        result = result.replacingOccurrences(of: "! ", with: "!\n")
        
        // If the font is large (>32pt), also break at phrase boundaries to
        // allow the text to use even larger fonts by distributing across lines
        if fontSize >= 32 {
            // Break after commas (clause boundaries)
            result = result.replacingOccurrences(of: ", ", with: ",\n")
        }
        
        if fontSize >= 38 {
            // Break at conjunctions and prepositions for maximum distribution
            let phraseBreaks = [" and ", " but ", " or ", " for ", " nor ", " yet ", " so ",
                                " that ", " which ", " who ", " when ", " where ", " while ",
                                " because ", " although ", " though ", " unless ", " until ",
                                " before ", " after ", " since ", " through ", " with ", " without ",
                                " upon ", " into ", " onto ", " within ", " between ", " among "]
            for phrase in phraseBreaks {
                result = result.replacingOccurrences(of: phrase, with: "\n" + phrase.trimmingCharacters(in: .whitespaces) + " ")
            }
        }
        
        // Clean up excessive newlines
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Text Drawing
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    private func drawTitle(_ title: String) {
        let cleanTitle = title.replacingOccurrences(
            of: "^Today[''']s Wisdom:\\s*",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        let font = NSFont.systemFont(ofSize: 48, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: centeredParagraphStyle(lineSpacing: 4)
        ]
        
        let titleRect = NSRect(x: 80, y: imageSize.height - 200, width: imageSize.width - 160, height: 120)
        cleanTitle.uppercased().draw(in: titleRect, withAttributes: attributes)
    }
    
    private func drawContent(_ content: String) {
        let contentRect = NSRect(x: 80, y: 160, width: imageSize.width - 160, height: imageSize.height - 340)
        
        // Adaptive font sizing algorithm:
        // 1. Start at maximum font size
        // 2. Format text with phrase breaks appropriate for that font size
        // 3. Measure the formatted text
        // 4. If it fits, draw it centered vertically; otherwise shrink and repeat
        let maxFont: CGFloat = 48
        let minFont: CGFloat = 16
        var fontSize = maxFont
        
        while fontSize >= minFont {
            let formatted = formatContentForDisplay(content, targetWidth: contentRect.width, fontSize: fontSize)
            let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
            let lineSpace = max(4, fontSize * 0.3)
            let style = centeredParagraphStyle(lineSpacing: lineSpace)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: style
            ]
            let boundingRect = (formatted as NSString).boundingRect(
                with: NSSize(width: contentRect.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            if boundingRect.height <= contentRect.height {
                // Vertically center the text
                let yOffset = (contentRect.height - boundingRect.height) / 2
                let drawRect = NSRect(x: contentRect.minX,
                                      y: contentRect.minY + yOffset,
                                      width: contentRect.width,
                                      height: boundingRect.height + 10)
                formatted.draw(in: drawRect, withAttributes: attrs)
                return
            }
            fontSize -= 1  // Fine-grained 1pt steps for optimal fill
        }
        
        // Fallback at minimum size
        let formatted = formatContentForDisplay(content, targetWidth: contentRect.width, fontSize: minFont)
        let font = NSFont.systemFont(ofSize: minFont, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: centeredParagraphStyle(lineSpacing: 4)
        ]
        formatted.draw(in: contentRect, withAttributes: attrs)
    }
    
    private func drawReference(_ reference: String) {
        let font = NSFont.systemFont(ofSize: 40, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: goldColor,
            .paragraphStyle: centeredParagraphStyle(lineSpacing: 4)
        ]
        
        let refRect = NSRect(x: 80, y: 135, width: imageSize.width - 160, height: 60)
        ("— " + reference).draw(in: refRect, withAttributes: attributes)
    }
    
    private func drawWatermark() {
        let font = NSFont.systemFont(ofSize: 36, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: goldColor,
            .paragraphStyle: centeredParagraphStyle(lineSpacing: 4)
        ]
        
        let watermarkRect = NSRect(x: 100, y: 80, width: imageSize.width - 200, height: 60)
        watermarkText.draw(in: watermarkRect, withAttributes: attributes)
    }
    
    private func centeredParagraphStyle(lineSpacing: CGFloat = 4) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = lineSpacing
        return style
    }
    
    private func leftAlignedParagraphStyle(lineSpacing: CGFloat = 4) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineSpacing = lineSpacing
        return style
    }
}

// MARK: - NSBezierPath convenience
extension NSBezierPath {
    @discardableResult
    func apply(_ block: (NSBezierPath) -> Void) -> NSBezierPath {
        block(self)
        return self
    }
}
